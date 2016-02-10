import h5py as h5
import numpy as np


class DataSet:
    feature_size = 400
    polyphony_label_size = 11
    note_label_size = 60
    onset_label_size = 2
    step_size = 1024

    def __init__(self, file_name):
        self.file_name = file_name
        self.h5_file = h5.File(file_name, "r")
        self.present_index = 0
        self.sample_count = self.h5_file["features_length"].shape[0]

    def next_batch(self, batch_size):
        if (self.present_index + batch_size > self.sample_count):
            self.present_index = 0

        features_length_d = self.h5_file["features_length"]
        sequence_length_d = self.h5_file["sequence_length"]

        event_note_d = self.h5_file["event_note"]
        event_offset_d = self.h5_file["event_offset"]
        features_polyphony_values_d = self.h5_file["features_polyphony_values"]

        peak_locations_d = self.h5_file["peak_locations"]
        peak_heights_d = self.h5_file["peak_heights"]
        spectrum_d = self.h5_file["spectrum"]
        spectrum_flux_d = self.h5_file["spectrum_flux"]

        features = np.concatenate((spectrum_d[self.present_index:self.present_index+batch_size, :, :],
                                   spectrum_flux_d[self.present_index:self.present_index+batch_size, :, :],
                                   peak_heights_d[self.present_index:self.present_index+batch_size, :, :],
                                   peak_locations_d[self.present_index:self.present_index+batch_size, :, :]), axis=2)

        # Labels:
        note_label_events_raw = np.expand_dims(event_note_d[self.present_index:self.present_index+batch_size, :, :], 2)
        note_label_events_inverse = 1 - note_label_events_raw
        note_label_events = np.concatenate((note_label_events_raw, note_label_events_inverse), axis=2)

        note_labels_zeros = np.zeros((batch_size, features.shape[1], 1, note_label_events_raw.shape[3]))
        note_labels_ones = np.ones((batch_size, features.shape[1], 1, note_label_events_raw.shape[3]))
        note_labels= np.concatenate((note_labels_zeros, note_labels_ones), axis=2)

        for i in xrange(batch_size):
            sequence_count = min(sequence_length_d[i + self.present_index], 20)
            for j in xrange(sequence_count):
                sequence_index = min(event_offset_d[i + self.present_index, j] // DataSet.step_size, 42)
                note_labels[i, sequence_index, ...] = note_label_events[i, j, ...]


        polyphony_labels_raw = features_polyphony_values_d[self.present_index:self.present_index+batch_size, :].astype(int)
        polyphony_labels = np.eye(DataSet.polyphony_label_size)[polyphony_labels_raw]

        onset_labels = note_labels.any(axis=3)

        feature_lengths = features_length_d[self.present_index:self.present_index+batch_size]
        sequence_lengths = sequence_length_d[self.present_index:self.present_index+batch_size]

        self.present_index += batch_size

        return (features, feature_lengths), (note_labels, polyphony_labels, onset_labels), sequence_lengths
