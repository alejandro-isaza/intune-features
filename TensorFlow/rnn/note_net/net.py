import tensorflow as tf
from tensorflow.models.rnn import rnn, rnn_cell
import numpy as np

import runner


def run_net(features, feature_lengths, lstm_units, layer_count):
    note_W = tf.Variable(tf.zeros([lstm_units, 2 * runner.note_label_size]), name="note_ip_weights")
    note_b = tf.Variable(tf.zeros([2 * runner.note_label_size]), name="note_ip_biases")

    polyphony_W = tf.Variable(tf.zeros([lstm_units, runner.polyphony_label_size]), name="polyphony_ip_weights")
    polyphony_b = tf.Variable(tf.zeros([runner.polyphony_label_size]), name="polyphony_ip_biases")

    onset_W = tf.Variable(tf.zeros([lstm_units, runner.onset_label_size]), name="onset_ip_weights")
    onset_b = tf.Variable(tf.zeros([runner.onset_label_size]), name="onset_ip_biases")

    lstm = rnn_cell.BasicLSTMCell(lstm_units)
    stacked_lstm = rnn_cell.MultiRNNCell([lstm] * layer_count)

    rnn_out, state = rnn.rnn(stacked_lstm, features, dtype=tf.float32, sequence_length=feature_lengths)

    note_logits = tf.concat(1, [tf.reshape(tf.matmul(t, note_W) + note_b, [runner.batch_size, 1, 2, runner.note_label_size]) for t in rnn_out])
    polyphony_logits = tf.concat(1, [tf.reshape(tf.matmul(t, polyphony_W) + polyphony_b, [runner.batch_size, 1, runner.polyphony_label_size]) for t in rnn_out])
    onset_logits = tf.concat(1, [tf.reshape(tf.matmul(t, onset_W) + onset_b, [runner.batch_size, 1, runner.onset_label_size]) for t in rnn_out])

    return note_logits, polyphony_logits, onset_logits

def correct((note_labels, note_logits), (polyphony_labels, polyphony_logits), (onset_labels, onset_logits), feature_lengths):
    label_polyphonies = np.argmax(polyphony_labels, axis=2)
    logit_polyphonies = np.argmax(polyphony_logits, axis=2)

    scores = []
    for i in xrange(runner.batch_size):
        length = feature_lengths[i]
        for j in xrange(length):
            label_onset = np.argmax(onset_labels[i, j, :])[0]
            logit_onset = np.argmax(onset_logits[i, j, :])[0]

            if label_onset == 1:
                label_polyphony = label_polyphonies[i, j]
                top_labels = np.argpartition(note_labels[i, j, 0, :], -label_polyphony)[-label_polyphony:]
            else:
                top_labels = []

            if logit_onset == 1:
                logit_polyphony = logit_polyphonies[i, j]
                top_logits = np.argpartition(note_logits[i, j, 0, :], -logit_polyphony)[-logit_polyphony:]
            else:
                top_logits = []

            scores.append(edit_distance(top_labels, top_logits))

    return np.mean(scores)

def edit_distance(s, t):
    n = s.size
    m = t.size
    d = np.zeros((n+1, m+1))
    d[:, 0] = np.arange(n+1)
    d[0, :] = np.arange(m+1)

    for j in xrange(0, m):
        for i in xrange(0, n):
            if s[i] == t[j]:
                d[i+1, j+1] = d[i, j]
            else:
                d[i+1, j+1] = min(d[i, j+1] + 1,
                                  d[i+1, j] + 1,
                                  d[i, j] + 1)

    return d[n, m]
