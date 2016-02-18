import tensorflow as tf
import numpy as np
import h5py

from tensorflow.models.rnn import rnn, rnn_cell

from data_set import DataSet
import net

learning_rate = 0.001
max_epoch = 20000

batch_size = 150

lstm_units = 20
layer_count = 3

train_data = DataSet("Training")
test_data = DataSet("Testing")

def fill_batch_vars(dataset, feature_var, note_label_var, polyphony_label_var, onset_label_var, feature_length_var):
    (features, feature_lengths), (note_labels, polyphony_labels, onset_labels) = dataset.next_batch(batch_size)
    feed_dict = {
        feature_var: features,
        note_label_var: note_labels,
        polyphony_label_var: polyphony_labels,
        onset_label_var: onset_labels,
        feature_length_var: feature_lengths,
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
        features_placeholder = tf.placeholder(tf.float32, shape=(batch_size, DataSet.max_sequence_length, train_data.feature_size))
        feature_lengths_placeholder = tf.placeholder(tf.int64, shape=(batch_size))
        note_labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size, DataSet.max_sequence_length, 2, DataSet.note_label_size))
        polyphony_labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size, DataSet.max_sequence_length, DataSet.polyphony_label_size))
        onset_labels_placeholder = tf.placeholder(tf.float32, shape=(batch_size, DataSet.max_sequence_length, DataSet.onset_label_size))

        features = [tf.squeeze(t) for t in tf.split(1, DataSet.max_sequence_length, features_placeholder)]

        note_logits, polyphony_logits, onset_logits = net.run_net(features, feature_lengths_placeholder, lstm_units, layer_count)

        loss = (tf.nn.l2_loss(polyphony_labels_placeholder-polyphony_logits) + tf.nn.l2_loss(onset_labels_placeholder-onset_logits)) / (batch_size)

        optimizer = tf.train.AdamOptimizer(learning_rate)
        global_step = tf.Variable(0, name='global_step', trainable=False)
        train_op = optimizer.minimize(loss, global_step=global_step)

        init = tf.initialize_all_variables()
        sess.run(init)

        for i in xrange(max_epoch):
            feed_dict = fill_batch_vars(train_data, features_placeholder, note_labels_placeholder, polyphony_labels_placeholder, onset_labels_placeholder, feature_lengths_placeholder)
            percent_list = []

            if i % 100 == 0:
                _, batch_loss = sess.run([train_op, loss], feed_dict=feed_dict)
                np_note_logits, np_polyphony_logits, np_onset_logits = sess.run([note_logits, polyphony_logits, onset_logits], feed_dict=feed_dict)
                np_note_labels, np_polyphony_labels, np_onset_labels = (feed_dict[note_labels_placeholder], feed_dict[polyphony_labels_placeholder], feed_dict[onset_labels_placeholder])
                feature_lengths = feed_dict[feature_lengths_placeholder]
                score = net.correct((np_note_labels, np_note_logits), (np_polyphony_labels, np_polyphony_logits), (np_onset_labels, np_onset_logits), feature_lengths)
                print("%d | batch loss: %f, score: %f" % (i, batch_loss / batch_size, score))

                if i % 500 == 0:
                    feed_dict = fill_batch_vars(test_data, features_placeholder, note_labels_placeholder, polyphony_labels_placeholder, onset_labels_placeholder, feature_lengths_placeholder)
                    test_percent = sess.run([loss], feed_dict=feed_dict)

                    np_note_logits, np_polyphony_logits, np_onset_logits = sess.run([note_logits, polyphony_logits, onset_logits], feed_dict=feed_dict)
                    np_note_labels, np_polyphony_labels, np_onset_labels = (feed_dict[note_labels_placeholder], feed_dict[polyphony_labels_placeholder], feed_dict[onset_labels_placeholder])
                    feature_lengths = feed_dict[feature_lengths_placeholder]
                    score = net.correct((np_note_labels, np_note_logits), (np_polyphony_labels, np_polyphony_logits), (np_onset_labels, np_onset_logits), feature_lengths)

                    print("     %d Testing loss: %f, score: %f" % (i, test_percent[0], score))
                    exportToHDF5(tf.trainable_variables(), sess)
                    print("     exported.")

            else:
                _ = sess.run([train_op], feed_dict=feed_dict)
