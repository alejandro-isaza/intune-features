import h5py as h5
import numpy as np


class DataSet:
    def __init__(self, file_name):
        self.file_name = file_name
        self.h5_file = h5.File(file_name, "r")
        self.present_index = 0

    def next_batch(batch_size):
        size_d = self.h5_file["sequence_size"]
        sequence_d = self.h5_file["sequences"]
        label_d = self.h5_file["labels"]

        sequence_sizes = size_d[self.present_index:self.present_index+batch_size]
        sequences = []
        labels = []
        for i in xrange(batch_size):
            size = sequence_sizes[i]
            sequence = sequence_d[self.present_index+i, 0:size, :]
            label = label_d[self.present_index+i, 0:size, :]

            sequences.append(sequence)
            labels.append(label)

        return sequences, labels
