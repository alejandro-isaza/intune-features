import tensorflow as tf
import numpy as np
import h5py

from tensorflow.models.rnn import rnn, rnn_cell

from data_set import DataSet

learning_rate = 0.001
max_epoch = 2000

batch_size = 150

lstm_units = 20
layer_count = 3

max_sequence_length = 43

train_data = DataSet("training.h5")
test_data = DataSet("testing.h5")

def fill_batch_vars(dataset, feature_var, label_var, length_var):
    data, label, length = dataset.next_batch(batch_size)
    feed_dict = {
        feature_var: data,
        label_var: label,
        length_var: length
    }
    return feed_dict

def exportToHDF5(variables, session):
    file = h5py.File("net.h5", "w")

    for variable in variables:
        name = variable.name.replace("/","")[:-2]
        print(name)
        dataset = file.create_dataset(name, variable.get_shape(), dtype=variable.dtype.as_numpy_dtype)
        dataset[...] = variable.eval(session)

if __name__ == '__main__':
    with tf.Graph().as_default(), tf.Session() as sess:
        features_placeholder = tf.placeholder(tf.float32, shape=(batch_size, max_sequence_length, train_data.feature_size))
        sequence_lengths = tf.placeholder(tf.int64, shape=(batch_size))
        labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size, max_sequence_length, 1))

        W = tf.Variable(tf.zeros([2 * lstm_units, 2]), name="ipWeights")
        b = tf.Variable(tf.zeros([2]), name="ipBiases")

        f_lstm = rnn_cell.BasicLSTMCell(lstm_units)
        f_stacked_lstm = rnn_cell.MultiRNNCell([f_lstm] * layer_count)

        r_lstm = rnn_cell.BasicLSTMCell(lstm_units)
        r_stacked_lstm = rnn_cell.MultiRNNCell([r_lstm] * layer_count)

        features = [tf.squeeze(t) for t in tf.split(1, max_sequence_length, features_placeholder)]

        rnn_out = rnn.bidirectional_rnn(f_stacked_lstm, r_stacked_lstm, features, dtype=tf.float32, sequence_length=sequence_lengths)

        logits_large = tf.concat(1, [tf.reshape(tf.matmul(t, W) + b, [batch_size, 1, 2]) for t in rnn_out])
        logits = tf.reshape(logits_large, [batch_size * max_sequence_length, 2])

        label_inverse = 1 - labels_placeholder
        labels = tf.reshape(tf.concat(2, [labels_placeholder, label_inverse]), [batch_size * max_sequence_length, 2])

        loss = tf.reduce_mean(tf.nn.softmax_cross_entropy_with_logits(logits, labels))
        correct = tf.reduce_mean(tf.to_float(tf.equal(tf.argmax(logits, 1), tf.argmax(labels, 1))))

        optimizer = tf.train.AdamOptimizer(learning_rate)
        global_step = tf.Variable(0, name='global_step', trainable=False)
        train_op = optimizer.minimize(loss, global_step=global_step)

        init = tf.initialize_all_variables()
        sess.run(init)

        # REMINDER: labels needs to be shaped like [time][batch_size][fw_output + bw_output]
        for i in xrange(max_epoch):
            feed_dict = fill_batch_vars(train_data, features_placeholder, labels_placeholder, sequence_lengths)
            percent_list = []

            if i % 100 == 0:
                _, batch_loss, batch_percent = sess.run([train_op, loss, correct], feed_dict=feed_dict)
                percent_list.append(batch_percent)
                percent = np.mean(percent_list)
                percent_list = []
                print("%d | batch loss: %f, percent: %f%%" % (i, batch_loss, percent))
                exportToHDF5(tf.trainable_variables(), sess)

            if i % 10000 == 0:
                feed_dict = fill_batch_vars(test_data, features_placeholder, labels_placeholder, sequence_lengths)
                test_percent = sess.run([correct], feed_dict=feed_dict)
                print("    %d Testing percent: %f" % (i, test_percent[0]))

            _, batch_percent = sess.run([train_op, correct], feed_dict=feed_dict)
            percent_list.append(batch_percent)
