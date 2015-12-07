# Copyright 2015 Venture Media Labs. All Rights Reserved.

"""Trains and Evaluates the Intune network using a feed dictionary."""

# pylint: disable=missing-docstring

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import numpy
import tensorflow as tf
import h5py

import data_set
import SOM

# Basic model parameters as external flags.
flags = tf.app.flags
FLAGS = flags.FLAGS
flags.DEFINE_integer('width', 20, 'SOM width.')
flags.DEFINE_integer('height', 20, 'SOM height.')
flags.DEFINE_integer('train_size', 100000, 'Train data set size.')
flags.DEFINE_integer('map_size', 1000, 'Map data set size.')
flags.DEFINE_string('features', 'training.h5', 'File to read features from')
flags.DEFINE_string('output', 'som.h5', 'File to write the som to')


def run():
    """Train a SOM and map features to it."""
    ds = data_set.DataSet(FLAGS.features)
    som = SOM.SOM(FLAGS.width, FLAGS.height, ds.example_size, n_iterations=1)

    print("Training...")
    input_data = ds.next_batch(FLAGS.train_size)[0]
    input_vectors = [numpy.squeeze(subarray) for subarray in numpy.split(input_data, FLAGS.train_size)]
    som.train(input_vectors)

    print("Mapping...")
    map_data, map_on_labels, map_onset_labels = ds.next_batch(FLAGS.map_size)
    map_vectors = [numpy.squeeze(subarray) for subarray in numpy.split(map_data, FLAGS.map_size)]
    coords = som.map_vects(map_vectors)

    print("Writing...")
    hf = h5py.File(FLAGS.output, 'w')
    hf.create_dataset("som", data=coords)
    hf.create_dataset("on_label", data=map_on_labels)
    hf.create_dataset("onset_label", data=map_onset_labels)

def main(_):
    run()

if __name__ == '__main__':
    tf.app.run()
