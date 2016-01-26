import h5py as h5
import numpy as np


class DataSet:
    def __init__(self, file_name):
        self.file_name = file_name
        self.h5_file = h5.File(file_name, "r")
        self.present_index = 0

    def next_batch(batch_size):
        features_length_d = self.h5_file["features_length"]
        features_onset_values_d = self.h5_file["features_onset_values"]

        peak_locations_d = self.h5_file["peak_locations"]
        peak_heights_d = self.h5_file["peak_heights"]
        spectrum_d = self.h5_file["spectrum"]
        spectrum_flux_d = self.h5_file["spectrum_flux"]

        sequence_sizes = features_length_d[self.present_index:self.present_index+batch_size]
        sequences = []
        labels = []
        for i in xrange(batch_size):
            size = sequence_sizes[i]
            sequence = np.concatenate((spectrum_d[self.present_index, 0:size, :],
                                       spectrum_flux_d[self.present_index, 0:size, :],
                                       peak_heights_d[self.present_index, 0:size, :],
                                       peak_locations_d[self.present_index, 0:size, :]), axis=2)
            label = features_onset_values_d[self.present_index, 0:size, :]

            sequences.append(sequence)
            labels.append(label)

            self.present_index += 1

        return sequences, labels
