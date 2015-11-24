# Copyright 2015 Venture Media Labs. All Rights Reserved.

"""Trains and Evaluates the Intune network using a feed dictionary."""

# pylint: disable=missing-docstring

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import os.path
import time

import tensorflow.python.platform
import numpy
from six.moves import xrange  # pylint: disable=redefined-builtin
import tensorflow as tf

import data_set
import net

# Basic model parameters as external flags.
flags = tf.app.flags
FLAGS = flags.FLAGS
flags.DEFINE_float('learning_rate', 0.001, 'Initial learning rate.')
flags.DEFINE_integer('max_steps', 2000, 'Number of steps to run trainer.')
flags.DEFINE_integer('hidden1', 4096, 'Number of units in hidden layer 1.')
flags.DEFINE_integer('hidden2', 1024, 'Number of units in hidden layer 2.')
flags.DEFINE_integer('batch_size', 1024, 'Batch size.  '
                     'Must divide evenly into the dataset sizes.')
flags.DEFINE_string('training_data', 'training.h5',
                    'File to read training features from')
flags.DEFINE_string('testing_data', 'testing.h5',
                    'File to read testing features from')
flags.DEFINE_string('train_dir', 'data', 'Directory to put the training data.')


def placeholder_inputs(example_size, label_size, batch_size):
    """Generate placeholder variables to represent the the input tensors.

    These placeholders are used as inputs by the rest of the model building
    code and will be fed from the downloaded data in the .run() loop, below.

    Args:
        example_size: The number of features in each example.
        batch_size: The batch size will be baked into both placeholders.

    Returns:
        features_placeholder: Images placeholder.
        labels_placeholder: Labels placeholder.
    """
    # Note that the shapes of the placeholders match the shapes of the full
    # feature and label tensors, except the first dimension is now batch_size
    # rather than the full size of the train or test data sets.
    features_placeholder = tf.placeholder(tf.float32,
                                          shape=(batch_size, example_size))
    labels_placeholder = tf.placeholder(tf.float32,
                                        shape=(batch_size, label_size))
    return features_placeholder, labels_placeholder


def fill_feed_dict(data_set, features_pl, labels_pl):
    """Fills the feed_dict for training the given step.

    A feed_dict takes the form of:
    feed_dict = {
        <placeholder>: <tensor of values to be passed for placeholder>,
        ....
    }

    Args:
        data_set: The set of features and labels.
        features_pl: The features placeholder.
        labels_pl: The labels placeholder.

    Returns:
        feed_dict: The feed dictionary mapping from placeholders to values.
    """
    features_feed, labels_feed = data_set.next_batch(FLAGS.batch_size)
    feed_dict = {
        features_pl: features_feed,
        labels_pl: labels_feed,
    }
    return feed_dict


def do_eval(sess,
            score,
            features_placeholder,
            labels_placeholder,
            data_set):
    """Runs one evaluation against the full epoch of data.

    Args:
        sess: The session in which the model has been trained.
        score: The Tensor that returns the prediction score.
        features_placeholder: The features placeholder.
        labels_placeholder: The labels placeholder.
        data_set: The set of features and labels to evaluate.
    """
    # And run one epoch of eval.
    total_score = 0
    steps_per_epoch = data_set.example_count // FLAGS.batch_size
    feed_dict = fill_feed_dict(data_set,
                               features_placeholder,
                               labels_placeholder)
    score = sess.run(score, feed_dict=feed_dict)
    average_score = score / FLAGS.batch_size
    print('  Num examples: %d  score: %d  Average score @ 1: %0.04f' %
        (FLAGS.batch_size, score, average_score))


def run_training():
    """Train Intune for a number of steps."""

    train_data_set = data_set.DataSet(FLAGS.training_data)
    test_data_set = data_set.DataSet(FLAGS.testing_data)

    with tf.Graph().as_default():
        # Generate placeholders for the features and labels.
        features_placeholder, labels_placeholder = placeholder_inputs(
            train_data_set.example_size,
            train_data_set.label_size,
            FLAGS.batch_size)
        # Build a Graph that computes predictions from the inference model.
        logits = net.inference(features_placeholder,
                               train_data_set.example_size,
                               train_data_set.label_size,
                               FLAGS.hidden1,
                               FLAGS.hidden2)
        # Add to the Graph the Ops for loss calculation.
        loss = net.loss(logits, labels_placeholder)
        # Add to the Graph the Ops that calculate and apply gradients.
        train_op = net.training(loss, FLAGS.learning_rate)
        # Add the Op to compare the logits to the labels during evaluation.
        score = net.evaluation(logits, labels_placeholder)
        # Build the summary operation based on the TF collection of Summaries.
        summary_op = tf.merge_all_summaries()
        # Create a saver for writing training checkpoints.
        saver = tf.train.Saver()
        # Create a session for running Ops on the Graph.
        sess = tf.Session()
        # Run the Op to initialize the variables.
        init = tf.initialize_all_variables()
        sess.run(init)
        # Instantiate a SummaryWriter to output summaries and the Graph.
        summary_writer = tf.train.SummaryWriter(FLAGS.train_dir,
                                                graph_def=sess.graph_def)
        # And then after everything is built, start the training loop.
        for step in xrange(FLAGS.max_steps):
            start_time = time.time()
            # Fill a feed dictionary with the actual set of features and labels
            # for this particular training step.
            feed_dict = fill_feed_dict(train_data_set,
                                       features_placeholder,
                                       labels_placeholder)
            # Run one step of the model.  The return values are the activations
            # from the `train_op` (which is discarded) and the `loss` Op.  To
            # inspect the values of your Ops or variables, you may include them
            # in the list passed to sess.run() and the value tensors will be
            # returned in the tuple from the call.
            _, loss_value = sess.run([train_op, loss], feed_dict=feed_dict)
            duration = time.time() - start_time
            # Write the summaries and print an overview fairly often.
            if step % 100 == 0:
                # Print status to stdout.
                print('Step %d: loss = %.2f (%.3f sec)' % (step, loss_value, duration))
                # Update the events file.
                summary_str = sess.run(summary_op, feed_dict=feed_dict)
                summary_writer.add_summary(summary_str, step)
            # Save a checkpoint and evaluate the model periodically.
            if (step + 1) % 1000 == 0 or (step + 1) == FLAGS.max_steps:
                saver.save(sess, FLAGS.train_dir, global_step=step)
                # Evaluate against the training set.
                print('Training Data Eval:')
                do_eval(sess,
                        score,
                        features_placeholder,
                        labels_placeholder,
                        train_data_set)
                # Evaluate against the test set.
                print('Test Data Eval:')
                do_eval(sess,
                        score,
                        features_placeholder,
                        labels_placeholder,
                        test_data_set)


def main(_):
    run_training()


if __name__ == '__main__':
    tf.app.run()
