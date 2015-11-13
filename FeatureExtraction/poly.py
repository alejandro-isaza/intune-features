import sys

import tensorflow as tf
import numpy
import h5py as h5

BATCH_SIZE = 256
TEST_BATCH_SIZE = 100
NUM_EPOCHS = 10
SEED = None  # Set to None for random seed.

TRAINING_FILE = 'training_poly.h5'
TESTING_FILE = 'testing_poly.h5'


def load_file(filename):
    """Load data and labels from an HDF5 file"""
    h5file = h5.File(filename, 'r')
    labels = h5file['label'][()]
    bands = h5file['spectrum'][()]
    peakh = h5file['peak_heights'][()]
    peakl = h5file['peak_locations'][()]
    flux = h5file['spectrum_flux'][()]
    all_features = numpy.concatenate((bands, peakh, peakl, flux), axis=1)
    return all_features, labels

def load_batch(data, labels, size):
    """Load a batch of the given size"""
    assert data.shape[0] == labels.shape[0]
    data_size = labels.shape[0]
    label_size = labels.shape[1]
    example_size = data.shape[1]

    indexes = numpy.random.choice(data_size, size)
    batch_data = numpy.ndarray(shape=(size, example_size), dtype=numpy.float32)
    batch_labels = numpy.ndarray(shape=(size, label_size), dtype=numpy.float32)
    for i in xrange(size):
        index = indexes[i]
        batch_data[i, :] = data[index, :]
        batch_labels[i, :] = labels[index, :]
    return batch_data, batch_labels


def error_rate(predictions, labels):
    """Return the error rate based on dense predictions and 1-hot labels."""
    return numpy.linalg.norm(predictions - labels)


def main(argv=None):  # pylint: disable=unused-argument
    print 'Loading data...'
    training_data, training_labels = load_file(TRAINING_FILE)
    testing_data, testing_labels = load_file(TESTING_FILE)

    train_size = training_labels.shape[0]
    label_size = training_labels.shape[1]
    example_size = training_data.shape[1]
    print 'Training with %i examples (label size: %i, example size: %i)' % (train_size, label_size, example_size)

    with tf.Graph().as_default():
        train_data_node = tf.placeholder("float", shape=[BATCH_SIZE, example_size])
        test_data_node = tf.placeholder("float", shape=[TEST_BATCH_SIZE, example_size])
        train_labels_node = tf.placeholder("float", shape=[BATCH_SIZE, label_size])

        fc1_weights = tf.Variable(tf.truncated_normal([example_size, 4096], stddev=0.01, seed=SEED))
        fc1_biases = tf.Variable(tf.constant(0.0, shape=[4096]))
        fc2_weights = tf.Variable(tf.truncated_normal([4096, 2048], stddev=0.01, seed=SEED))
        fc2_biases = tf.Variable(tf.constant(0.0, shape=[2048]))
        fc3_weights = tf.Variable(tf.truncated_normal([2048, 1024], stddev=0.01, seed=SEED))
        fc3_biases = tf.Variable(tf.constant(0.0, shape=[1024]))
        fc4_weights = tf.Variable(tf.truncated_normal([1024, label_size], stddev=0.01, seed=SEED))
        fc4_biases = tf.Variable(tf.constant(0.0, shape=[label_size]))


        def model(data, train=False):
            hidden1 = tf.nn.relu(tf.matmul(data, fc1_weights) + fc1_biases)
            if train:
                hidden1 = tf.nn.dropout(hidden1, 0.5, seed=SEED)

            hidden2 = tf.nn.relu(tf.matmul(hidden1, fc2_weights) + fc2_biases)
            if train:
                hidden2 = tf.nn.dropout(hidden2, 0.5, seed=SEED)

            hidden3 = tf.nn.relu(tf.matmul(hidden2, fc3_weights) + fc3_biases)
            if train:
                hidden3 = tf.nn.dropout(hidden3, 0.5, seed=SEED)

            return tf.matmul(hidden3, fc4_weights) + fc4_biases

        logits = model(train_data_node, True)
        l2loss = tf.nn.l2_loss(logits - train_labels_node, name='loss')
        loss = tf.reduce_mean(l2loss, name='loss_mean')
        tf.scalar_summary(loss.op.name, loss)

        # L2 regularization for the fully connected parameters.
        regularizers = (tf.nn.l2_loss(fc1_weights) + tf.nn.l2_loss(fc1_biases) +
                        tf.nn.l2_loss(fc2_weights) + tf.nn.l2_loss(fc2_biases) +
                        tf.nn.l2_loss(fc3_weights) + tf.nn.l2_loss(fc3_biases) +
                        tf.nn.l2_loss(fc4_weights) + tf.nn.l2_loss(fc4_biases))
        # Add the regularization term to the loss.
        loss += 5e-4 * regularizers

        # Optimizer: set up a variable that's incremented once per batch and
        # controls the learning rate decay.
        batch = tf.Variable(0)
        # Decay once per epoch, using an exponential schedule
        learning_rate = tf.train.exponential_decay(
            0.001,               # Base learning rate.
            batch * BATCH_SIZE,  # Current index into the dataset.
            train_size,          # Decay step.
            0.95,                # Decay rate.
            staircase=True)
        # Use simple momentum for the optimization.
        optimizer = tf.train.MomentumOptimizer(learning_rate, 0.9).minimize(loss, global_step=batch)
        tf.scalar_summary(learning_rate.op.name, learning_rate)

        # Predictions for the minibatch, validation set and test set.
        train_prediction = tf.nn.softmax(logits)
        # We'll compute them only once in a while by calling their {eval()} method.
        test_prediction = tf.nn.softmax(model(test_data_node))

        summary_op = tf.merge_all_summaries()

        # Create a local session to run this computation.
        with tf.Session() as s:
            # Run all the initializers to prepare the trainable parameters.
            tf.initialize_all_variables().run()
            print 'Initialized!'

            summary_writer = tf.train.SummaryWriter('/tmp/poly_logs', graph_def=s.graph_def)

            # Loop through training steps.
            for step in xrange(int(NUM_EPOCHS * train_size / BATCH_SIZE)):
                batch_data, batch_labels = load_batch(training_data, training_labels, BATCH_SIZE)
                test_data, test_labels = load_batch(testing_data, testing_labels, TEST_BATCH_SIZE)

                # This dictionary maps the batch data (as a numpy array) to the
                # node in the graph is should be fed to.
                feed_dict = {
                    train_data_node: batch_data,
                    train_labels_node: batch_labels,
                    test_data_node: test_data
                }

                # Run the graph and fetch some of the nodes.
                _, l, lr, predictions = s.run([optimizer, loss, learning_rate, train_prediction], feed_dict=feed_dict)
                if step % 100 == 0:
                    print 'Epoch %.2f' % (float(step) * BATCH_SIZE / train_size)
                    print 'Minibatch loss: %.3f, learning rate: %.6f' % (l, lr)
                    print 'Minibatch error: %.1f' % error_rate(predictions, batch_labels)
                    print 'Validation error: %.1f' % error_rate(test_prediction.eval(feed_dict=feed_dict), test_labels)
                    sys.stdout.flush()

                    summary_str = s.run(summary_op, feed_dict=feed_dict)
                    summary_writer.add_summary(summary_str, step)

            # Finally print the result!
            test_error = error_rate(test_prediction.eval(feed_dict=feed_dict), test_labels)
            print 'Test error: %.1f' % test_error

if __name__ == '__main__':
    tf.app.run()
