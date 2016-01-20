import tensorflow as tf
from tensorflow.models.rnn import rnn, rnn_cell
import numpy as np

import data_set

learning_rate = 0.0001
max_epoch = 10000

batch_size = 10
num_steps = 40

lstm_units = 20
layer_count = 3

train_data = DataSet("training.h5")
test_data = DataSet("testing.h5")

def fill_batch_vars(dataset, feature_var, label_var):
    data, label = dataset.next_batch()
    feed_dict = {
        feature_var: data,
        label_var: label
    }
    return feed_dict

if __name__ == '__main__':
    with tf.Graph().as_default(), tf.Session() as sess:
        features_placeholder = tf.placeholder(tf.float32, shape=(batch_size, train_data.feature_size))
        labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size, train_data.label_size))

        f_lstm = rnn_cell.BasicLSTMCell(lstm_units)
        f_stacked_lstm = rnn_cell.MultiRNNCell([lstm] * layer_count)

        r_lstm = rnn_cell.BasicLSTMCell(lstm_units)
        r_stacked_lstm = rnn_cell.MultiRNNCell([lstm] * layer_count)

        logits = rnn.bidirectional_rnn(f_stacked_lstm, r_stacked_lstm, features_placeholder)
        loss = tf.nn.l2_loss(logits - labels_placeholder)
        loss = tf.reduce_mean(l2loss, name='l2loss_mean')


        optimizer = tf.train.GradientDescentOptimizer(learning_rate)
        global_step = tf.Variable(0, name='global_step', trainable=False)
        train_op = optimizer.minimize(total_loss, global_step=global_step)

        init = tf.initialize_all_variables()
        sess.run(init)

        # REMINDER: labels needs to be shaped like [time][batch_size][fw_output + bw_output]
        for i in xrange(max_epoch):
            feed_dict = fill_batch_vars(train_data, features_placeholder, labels_placeholder)
            _, batch_loss = sess.run([train_op, loss], feed_dict=feed_dict)
            print("Batch loss: %d" % (batch_loss))

            if i % 100 == 0:
                feed_dict = fill_batch_vars(test_data, features_placeholder, labels_placeholder)
                test_loss = sess.run([loss], feed_dict=feed_dict)
                print("    Testing loss: %d" % (test_loss))
