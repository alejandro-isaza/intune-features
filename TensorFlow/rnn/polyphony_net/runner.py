import tensorflow as tf
import numpy as np
import h5py

from tensorflow.models.rnn import rnn, rnn_cell

from data_set import DataSet

learning_rate = 0.001
max_epoch = 5000

batch_size = 100

lstm_units = 20
layer_count = 3

max_sequence_length = 43


train_data = DataSet("training.h5")
test_data = DataSet("testing.h5")

output_size = train_data.label_size

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
        dataset = file.create_dataset(name, variable.get_shape(), dtype=variable.dtype.as_numpy_dtype)
        dataset[...] = variable.eval(session)

if __name__ == '__main__':
    with tf.Graph().as_default(), tf.Session() as sess:
        features_placeholder = tf.placeholder(tf.float32, shape=(batch_size, max_sequence_length, train_data.feature_size))
        sequence_lengths = tf.placeholder(tf.int64, shape=(batch_size))
        labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size * max_sequence_length, output_size))


        W = tf.Variable(tf.zeros([lstm_units, output_size]))
        b = tf.Variable(tf.zeros([output_size]))

        lstm = rnn_cell.BasicLSTMCell(lstm_units)
        stacked_lstm = rnn_cell.MultiRNNCell([lstm] * layer_count)

        features = [tf.squeeze(t) for t in tf.split(1, max_sequence_length, features_placeholder)]

        rnn_out, state = rnn.rnn(stacked_lstm, features, dtype=tf.float32, sequence_length=sequence_lengths)

        logits_concat = tf.concat(1, [tf.reshape(tf.matmul(t, W) + b, [batch_size, 1, output_size]) for t in rnn_out])
        logits = tf.reshape(logits_concat, [batch_size * max_sequence_length, output_size])

        loss = tf.nn.l2_loss(labels_placeholder - logits)
        correct = 100 * tf.reduce_mean(tf.to_float(tf.equal(tf.argmax(labels_placeholder, 1), tf.argmax(logits, 1))))

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
                print("%d | batch loss: %f, percent: %f%%" % (i, batch_loss / batch_size, percent))

            if i % 500 == 0:
                feed_dict = fill_batch_vars(test_data, features_placeholder, labels_placeholder, sequence_lengths)
                test_percent = sess.run([correct], feed_dict=feed_dict)
                print("     %d Testing percent: %f" % (i, test_percent[0]))
                exportToHDF5(tf.trainable_variables(), sess)
                print("     exported.")


            _, batch_percent = sess.run([train_op, correct], feed_dict=feed_dict)
            percent_list.append(batch_percent)
