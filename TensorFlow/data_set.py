# Copyright 2015 Venture Media Labs. All Rights Reserved.

"""Functions for loading features from an HDF5 file."""

import h5py
import numpy


class DataSet(object):
    def __init__(self, filename):
        """Load data and labels from an HDF5 file"""
        h5file = h5py.File(filename, 'r')

        bands = h5file['bands'][()]
        peakh = h5file['peak_heights'][()]
        peakl = h5file['peak_locations'][()]
        flux = h5file['band_fluxes'][()]
        self._features = numpy.concatenate((bands, peakh, peakl, flux), axis=1)
        self._labels = h5file['label'][()]

        assert(self._labels.shape[0] == self._features.shape[0])
        self._example_count = self._labels.shape[0]
        self._example_size = data.shape[1]
        self._label_size = labels.shape[1]
        self._epochs_completed = 0
        self._index_in_epoch = 0
  
    @property
    def example_count(self):
        return self._example_count
  
    @property
    def example_size(self):
        return self._example_size
  
    @property
    def label_size(self):
        return self._label_size

    @property
    def labels(self):
        return self._labels
  
    @property
    def features(self):
        return self._features

    @property
    def epochs_completed(self):
        return self._epochs_completed

    def next_batch(self, batch_size):
        """Return the next `batch_size` examples from this data set."""
        start = self._index_in_epoch
        self._index_in_epoch += batch_size
        if self._index_in_epoch > self._num_examples:
            # Finished epoch
            self._epochs_completed += 1
            # Shuffle the data
            perm = numpy.arange(self._num_examples)
            numpy.random.shuffle(perm)
            self._features = self._features[perm]
            self._labels = self._labels[perm]
            # Start next epoch
            start = 0
            self._index_in_epoch = batch_size
            assert batch_size <= self._num_examples

        end = self._index_in_epoch
        return self._features[start:end], self._labels[start:end]
