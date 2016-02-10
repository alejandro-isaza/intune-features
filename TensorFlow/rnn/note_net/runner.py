import tensorflow as tf
import numpy as np
import h5py

from tensorflow.models.rnn import rnn, rnn_cell

from data_set import DataSet
import net

learning_rate = 0.001
max_epoch = 2000

batch_size = 150

lstm_units = 20
layer_count = 3

max_feature_length = 43

train_data = DataSet("training.h5")
test_data = DataSet("testing.h5")

note_label_size = train_data.note_label_size
polyphony_label_size =  train_data.polyphony_label_size
onset_label_size = train_data.onset_label_size

def fill_batch_vars(dataset, feature_var, note_label_var, polyphony_label_var, onset_label_var, feature_length_var, sequence_length_var):
    (features, feature_lengths), (note_labels, polyphony_labels, onset_labels), sequence_lengths = dataset.next_batch(batch_size)
    feed_dict = {
        feature_var: features,
        note_label_var: note_labels,
        polyphony_label_var: polyphony_labels,
        onset_label_var: onset_labels,
        feature_length_var: feature_lengths,
        sequence_length_var: sequence_lengths,
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
        features_placeholder = tf.placeholder(tf.float32, shape=(batch_size, max_feature_length, train_data.feature_size))
        sequence_lengths_placeholder = tf.placeholder(tf.int64, shape=(batch_size))
        feature_lengths_placeholder = tf.placeholder(tf.int64, shape=(batch_size))
        note_labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size, max_feature_length, 2, note_label_size))
        polyphony_labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size, max_feature_length, polyphony_label_size))
        onset_labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size, max_feature_length, onset_label_size))
        loss_placeholder = tf.placeholder(tf.float32, shape=(1))

        features = [tf.squeeze(t) for t in tf.split(1, max_feature_length, features_placeholder)]

        note_logits, polyphony_logits, onset_logits = net.run_net(features, feature_lengths_placeholder, lstm_units, layer_count)

        optimizer = tf.train.AdamOptimizer(learning_rate)
        global_step = tf.Variable(0, name='global_step', trainable=False)
        train_op = optimizer.minimize(loss_placeholder, global_step=global_step)

        init = tf.initialize_all_variables()
        sess.run(init)

        # REMINDER: labels needs to be shaped like [time][batch_size][fw_output + bw_output]
        for i in xrange(max_epoch):
            feed_dict = fill_batch_vars(train_data, features_placeholder, note_labels_placeholder, polyphony_labels_placeholder, onset_labels_placeholder, feature_lengths, sequence_lengths)
            percent_list = []

            if i % 100 == 0:
                _, batch_loss, batch_percent = sess.run([train_op, loss, correct], feed_dict=feed_dict)
                percent_list.append(batch_percent)
                percent = np.mean(percent_list)
                percent_list = []
                print("%d | batch loss: %f, percent: %f%%" % (i, batch_loss / batch_size, percent))

            if i % 500 == 0:
                feed_dict = fill_batch_vars(test_data, features_placeholder, note_labels_placeholder, polyphony_labels_placeholder, onset_labels_placeholder, feature_lengths, sequence_lengths)
                test_percent = sess.run([correct], feed_dict=feed_dict)
                print("     %d Testing percent: %f" % (i, test_percent[0]))
                exportToHDF5(tf.trainable_variables(), sess)
                print("     exported.")


            np_note_labels, np_note_logits, np_polyphony_labels, np_polyphony_logits, np_onset_labels, np_onset_logits, feature_lengths = sess.run([note_labels_placeholder, note_logits, polyphony_labels_placeholder, polyphony_logits, onset_labels_placeholder, onset_logits, feature_lengths_placeholder], feed_dict=feed_dict)
            loss = net.loss((np_note_labels, np_note_logits), (np_polyphony_labels, np_polyphony_logits), (np_onset_labels, np_onset_logits), feature_lengths)
            batch_percent = net.correct((np_note_labels, np_note_logits), (np_polyphony_labels, np_polyphony_logits), (np_onset_labels, np_onset_logits), feature_lengths)
            _ = sess.run([train_op], feed_dict={loss_placeholder: loss})

            percent_list.append(batch_percent)
