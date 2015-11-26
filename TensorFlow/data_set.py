# Copyright 2015 Venture Media Labs. All Rights Reserved.

"""Functions for loading features from an HDF5 file."""

from __future__ import absolute_import
from __future__ import print_function

import h5py
import numpy

class Batch:
    def __init__(self, batch_size, notes_count):
        self.count = 0
        self.zero_count = 0
        self.non_zero_count = 0

        self.batch_size = batch_size
        self.notes_count = notes_count
        self.labels = numpy.ndarray([batch_size, notes_count])
        self.datasets = numpy.ndarray([batch_size, 4, notes_count])

    def append(self, label, data):
        self.labels[self.count] = label
        self.datasets[self.count] = data
        self.count += 1
        if label.any():
            self.non_zero_count += 1
        else:
            self.zero_count += 1

    def data(self):
        return self.datasets.reshape(self.batch_size, 4 * self.notes_count)


class DataSet(object):
    def __init__(self, filename):
        """Load data and labels from an HDF5 file"""
        print("Loading data...")
        h5file = h5py.File(filename, 'r')

        self._spectrum = h5file['spectrum']
        self._heights = h5file['peak_heights']
        self._locations = h5file['peak_locations']
        self._flux = h5file['spectrum_flux']
        self._labels = h5file['label']

        assert(self._labels.shape[0] == self._spectrum.shape[0])
        self._example_count = self._labels.shape[0]
        self._example_size = self._spectrum.shape[1] + self._heights.shape[1] \
            + self._locations.shape[1] + self._flux.shape[1]
        self._label_size = self._labels.shape[1]
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
    def epochs_completed(self):
        return self._epochs_completed

    # def next_batch(self, batch_size):
    #     """Return the next `batch_size` examples from this data set."""
    #     start = self._index_in_epoch
    #     self._index_in_epoch += batch_size
    #     if self._index_in_epoch > self._example_count:
    #         # Finished epoch
    #         self._epochs_completed += 1
    #         # Start next epoch
    #         start = 0
    #         self._index_in_epoch = batch_size
    #         assert batch_size <= self._example_count
    #
    #     end = self._index_in_epoch
    #     batch = numpy.concatenate((
    #         self._spectrum[start:end, :],
    #         self._heights[start:end, :],
    #         self._locations[start:end, :],
    #         self._flux[start:end, :]),
    #         axis=1)
    #     return batch, self._labels[start:end].astype(float)

    def next_batch(self, batch_size):
        """Return the next `batch_size` examples from this data set."""
        start = self._index_in_epoch
        batch = Batch(batch_size, self._label_size)

        self._index_in_epoch += batch_size
        if self._index_in_epoch > self._example_count:
            # Finished epoch
            self._epochs_completed += 1
            # Start next epoch
            start = 0
            self._index_in_epoch = batch_size
            assert batch_size <= self._example_count

        index = 0
        while batch.count < batch_size:
            data = numpy.concatenate((
                self._spectrum[start + index:start + index + 1, :],
                self._heights[start + index:start + index + 1, :],
                self._locations[start + index:start + index + 1, :],
                self._flux[start + index:start + index + 1, :]),
                axis=0)
            if (not self._labels[index].any()) & batch.zero_count < batch_size // 2:
                batch.append(self._labels[index], data)
            elif self._labels[index].any():
                batch.append(self._labels[index], data)
            else:
                continue
            index += 1

        return batch.data(), batch.labels
