import h5py as h5
import numpy as np


class DataSet:
    def __init__(self, file_name):
        self.file_name = file_name
        self.h5_file = h5.File(file_name, "r")
        self.present_index = 0
        self.feature_size = 400
        self.sample_count = self.h5_file["features_length"].shape[0]

    def next_batch(self, batch_size):
        if (self.present_index + batch_size > self.sample_count):
            self.present_index = 0

        features_length_d = self.h5_file["features_length"]
        features_onset_values_d = self.h5_file["features_onset_values"]

        peak_locations_d = self.h5_file["peak_locations"]
        peak_heights_d = self.h5_file["peak_heights"]
        spectrum_d = self.h5_file["spectrum"]
        spectrum_flux_d = self.h5_file["spectrum_flux"]

        sequences = np.concatenate((spectrum_d[self.present_index:self.present_index+batch_size, :, :],
                                   spectrum_flux_d[self.present_index:self.present_index+batch_size, :, :],
                                   peak_heights_d[self.present_index:self.present_index+batch_size, :, :],
                                   peak_locations_d[self.present_index:self.present_index+batch_size, :, :]), axis=2)
        labels = np.expand_dims(features_onset_values_d[self.present_index:self.present_index+batch_size, :], 2)
        sequence_lengths = features_length_d[self.present_index:self.present_index+batch_size]

        self.present_index += batch_size

        return sequences, labels, sequence_lengths
