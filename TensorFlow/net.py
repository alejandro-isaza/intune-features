# Copyright 2015 Venture Media Labs. All Rights Reserved.

"""Build the Intune network.

Implements the inference/loss/training pattern for model building.

1. inference() - Builds the model as far as is required for running the network
   forward to make predictions.
2. loss() - Adds to the inference model the layers required to generate loss.
3. training() - Adds to the loss model the Ops required to generate and
   apply gradients.
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import h5py
import math
import tensorflow.python.platform
import tensorflow as tf


def inference(features, example_size, label_size, hidden1_units, hidden2_units):
    """Build the model up to where it may be used for inference.

    Args:
        features: Features placeholder.
        example_size: The number of features in each example.
        label_size: The number of labels.
        hidden1: Size of the first hidden layer.
        hidden2: Size of the second hidden layer.

    Returns:
        softmax_linear: Output tensor with the computed logits.
    """

    # Hidden 1
    with tf.name_scope('hidden1') as scope:
        weights = tf.Variable(
            tf.truncated_normal([example_size, hidden1_units],
                                stddev=1.0 / math.sqrt(float(example_size))),
            name='___weights')
        biases = tf.Variable(tf.zeros([hidden1_units]), name='___biases')
        hidden1 = tf.nn.relu(tf.matmul(features, weights) + biases)

    # Hidden 2
    with tf.name_scope('hidden2') as scope:
        weights = tf.Variable(
            tf.truncated_normal([hidden1_units, hidden2_units],
                                stddev=1.0 / math.sqrt(float(hidden1_units))),
            name='___weights')
        biases = tf.Variable(tf.zeros([hidden2_units]), name='___biases')
        hidden2 = tf.nn.relu(tf.matmul(hidden1, weights) + biases)

    # Linear
    with tf.name_scope('hidden3') as scope:
        weights = tf.Variable(
            tf.truncated_normal([hidden2_units, label_size],
                                stddev=1.0 / math.sqrt(float(hidden2_units))),
            name='___weights')
        biases = tf.Variable(tf.zeros([label_size]), name='___biases')
        logits = tf.matmul(hidden2, weights) + biases

    return logits


def loss(logits, labels):
    """Calculates the loss from the logits and the labels.

    Args:
        logits: Logits tensor, float - [batch_size, label_size].
        labels: Labels tensor, float - [batch_size, label_size].

    Returns:
        loss: Loss tensor of type float.
    """
    diff = logits - labels
    l2loss = tf.nn.l2_loss(diff, name='l2loss')
    loss = tf.reduce_mean(l2loss, name='l2loss_mean')
    return loss


def training(loss, learning_rate):
    """Sets up the training Ops.

    Creates a summarizer to track the loss over time in TensorBoard.

    Creates an optimizer and applies the gradients to all trainable variables.

    The Op returned by this function is what must be passed to the
    `sess.run()` call to cause the model to train.

    Args:
        loss: Loss tensor, from loss().
        learning_rate: The learning rate to use for gradient descent.

    Returns:
        train_op: The Op for training.
    """
    # Add a scalar summary for the snapshot loss.
    tf.scalar_summary(loss.op.name, loss)
    # Create the gradient descent optimizer with the given learning rate.
    optimizer = tf.train.GradientDescentOptimizer(learning_rate)
    # Create a variable to track the global step.
    global_step = tf.Variable(0, name='global_step', trainable=False)
    # Use the optimizer to apply the gradients that minimize the loss
    # (and also increment the global step counter) as a single training step.
    train_op = optimizer.minimize(loss, global_step=global_step)
    return train_op

def evaluation(logits, labels):
    """Evaluate the quality of the logits at predicting the label.

    Args:
        logits: Logits tensor, float - [batch_size, label_size].
        labels: Labels tensor, float - [batch_size, label_size].

    Returns:
        A scalar float32 with a measure of the distance between the predictions
        and the labels.
    """
    l2loss = tf.nn.l2_loss(logits - labels)
    return tf.reduce_mean(l2loss)

def exportToHDF5(variables, session):
    file = h5py.File("net.h5", "w")

    for variable in variables:
        name = variable.name.replace("/","")[:-2]
        print(name)
        dataset = file.create_dataset(name, variable.get_shape(), dtype=variable.dtype.as_numpy_dtype)
        dataset[...] = variable.eval(session)
