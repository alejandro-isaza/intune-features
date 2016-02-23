import tensorflow as tf
from tensorflow.models.rnn import rnn, rnn_cell
import numpy as np

import runner
from data_set import DataSet

threshold = 0.05

def run_net(features, feature_lengths, lstm_units, layer_count):
    note_W = tf.Variable(tf.zeros([lstm_units, DataSet.note_label_size]), name="note_ip_weights")
    note_b = tf.Variable(tf.zeros([DataSet.note_label_size]), name="note_ip_biases")

    polyphony_W = tf.Variable(tf.zeros([lstm_units, DataSet.polyphony_label_size]), name="polyphony_ip_weights")
    polyphony_b = tf.Variable(tf.zeros([DataSet.polyphony_label_size]), name="polyphony_ip_biases")

    onset_W = tf.Variable(tf.zeros([lstm_units, DataSet.onset_label_size]), name="onset_ip_weights")
    onset_b = tf.Variable(tf.zeros([DataSet.onset_label_size]), name="onset_ip_biases")

    lstm = rnn_cell.BasicLSTMCell(lstm_units)
    stacked_lstm = rnn_cell.MultiRNNCell([lstm] * layer_count)

    rnn_out, state = rnn.rnn(stacked_lstm, features, dtype=tf.float32, sequence_length=feature_lengths)

    note_logits = tf.concat(1, [tf.reshape(tf.matmul(t, note_W) + note_b, [runner.batch_size, 1, DataSet.note_label_size]) for t in rnn_out])
    polyphony_logits = tf.concat(1, [tf.reshape(tf.matmul(t, polyphony_W) + polyphony_b, [runner.batch_size, 1]) for t in rnn_out])
    onset_logits = tf.concat(1, [tf.reshape(tf.matmul(t, onset_W) + onset_b, [runner.batch_size, 1, DataSet.onset_label_size]) for t in rnn_out])

    return note_logits, polyphony_logits, onset_logits

def correct((note_labels, note_logits), (polyphony_labels, polyphony_logits), (onset_labels, onset_logits), feature_lengths):
    score = 0.0
    count = 0.0
    for i in xrange(runner.batch_size):
        length = feature_lengths[i]
        for j in xrange(length):
            note_label = note_labels[i, j]
            note_logit = note_logits[i, j]
            polyphony_label = polyphony_labels[i, j:j+1]
            polyphony_logit = polyphony_logits[i, j:j+1]
            onset_label = onset_labels[i, j]
            onset_logit = onset_logits[i, j]
            score += edit_distance(note_label, note_logit)
            score += edit_distance(polyphony_label, polyphony_logit)
            score += edit_distance(onset_label, onset_logit)
            count += 91.0

    return 100 * score / count

def edit_distance(s, t):
    n = s.size
    m = t.size
    d = np.zeros((n+1, m+1))
    d[:, 0] = np.arange(n+1)
    d[0, :] = np.arange(m+1)

    for j in xrange(0, m):
        for i in xrange(0, n):
            if threshold > abs(s[i] - t[j]):
                d[i+1, j+1] = d[i, j]
            else:
                d[i+1, j+1] = min(d[i, j+1] + 1,
                                  d[i+1, j] + 1,
                                  d[i, j] + 1)

    return d[n, m]
