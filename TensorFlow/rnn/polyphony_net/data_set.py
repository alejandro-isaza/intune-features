import h5py as h5
import numpy as np
np.set_printoptions(threshold=np.nan)

class DataSet:
    def __init__(self, file_name):
        self.file_name = file_name
        self.h5_file = h5.File(file_name, "r")
        self.present_index = 0
        self.feature_size = 400
        self.label_size = 16
        self.sample_count = self.h5_file["features_length"].shape[0]

    def next_batch(self, batch_size):
        if (self.present_index + batch_size > self.sample_count):
            self.present_index = 0

        offset_d = self.h5_file["offset"]
        file_id_d = self.h5_file["file_id"]
        file_list_d = self.h5_file["file_list"]

        features_length_d = self.h5_file["features_length"]
        features_polyphony_values_d = self.h5_file["features_polyphony_values"]

        peak_locations_d = self.h5_file["peak_locations"]
        peak_heights_d = self.h5_file["peak_heights"]
        spectrum_d = self.h5_file["spectrum"]
        spectrum_flux_d = self.h5_file["spectrum_flux"]

        sequences = np.concatenate((spectrum_d[self.present_index:self.present_index+batch_size, :, :],
                                   spectrum_flux_d[self.present_index:self.present_index+batch_size, :, :],
                                   peak_heights_d[self.present_index:self.present_index+batch_size, :, :],
                                   peak_locations_d[self.present_index:self.present_index+batch_size, :, :]), axis=2)

        labels_raw = features_polyphony_values_d[self.present_index:self.present_index+batch_size, :].astype(int)
        labels_reshape = np.reshape(labels_raw, (batch_size * features_polyphony_values_d.shape[1]))
        labels = np.eye(self.label_size)[labels_reshape]
        sequence_lengths = features_length_d[self.present_index:self.present_index+batch_size]

        self.present_index += batch_size

        return sequences, labels, sequence_lengths
