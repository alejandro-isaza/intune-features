import tensorflow as tf
from tensorflow.models.rnn import rnn, rnn_cell

from data_set import DataSet

learning_rate = 0.0001
max_epoch = 10000

batch_size = 10
num_steps = 40

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

if __name__ == '__main__':
    with tf.Graph().as_default(), tf.Session() as sess:
        features_placeholder = tf.placeholder(tf.float32, shape=(batch_size, max_sequence_length, train_data.feature_size))
        sequence_lengths = tf.placeholder(tf.int64, shape=(batch_size))
        labels_placeholder = tf.placeholder(tf.float32)

        W = tf.Variable(tf.zeros([2 * lstm_units, 1]))
        b = tf.Variable(tf.zeros([1]))

        f_lstm = rnn_cell.BasicLSTMCell(lstm_units)
        f_stacked_lstm = rnn_cell.MultiRNNCell([f_lstm] * layer_count)

        r_lstm = rnn_cell.BasicLSTMCell(lstm_units)
        r_stacked_lstm = rnn_cell.MultiRNNCell([r_lstm] * layer_count)

        features = [tf.squeeze(t) for t in tf.split(1, max_sequence_length, features_placeholder)]

        rnn_out = rnn.bidirectional_rnn(f_stacked_lstm, r_stacked_lstm, features, dtype=tf.float32, sequence_length=sequence_lengths)
        logits = tf.concat(1, [tf.matmul(t, W) + b for t in rnn_out])[:, :]
        loss = tf.reduce_mean(tf.nn.softmax_cross_entropy_with_logits(logits, labels_placeholder))


        optimizer = tf.train.GradientDescentOptimizer(learning_rate)
        global_step = tf.Variable(0, name='global_step', trainable=False)
        train_op = optimizer.minimize(loss, global_step=global_step)

        init = tf.initialize_all_variables()
        sess.run(init)

        # REMINDER: labels needs to be shaped like [time][batch_size][fw_output + bw_output]
        for i in xrange(max_epoch):
            feed_dict = fill_batch_vars(train_data, features_placeholder, labels_placeholder, sequence_lengths)
            _, batch_loss = sess.run([train_op, loss], feed_dict=feed_dict)
            print("Batch loss: %d" % (batch_loss))

            if i % 100 == 0:
                feed_dict = fill_batch_vars(test_data, features_placeholder, labels_placeholder, sequence_lengths)
                test_loss = sess.run([loss], feed_dict=feed_dict)
                print("    Testing loss: %d" % (test_loss[0]))
