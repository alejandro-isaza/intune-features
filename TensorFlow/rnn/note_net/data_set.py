import h5py as h5
import numpy as np

import os


class DataSet:
    feature_size = 400
    polyphony_label_size = 1
    note_label_size = 88
    onset_label_size = 2
    step_size = 1024
    min_sequence_length = 15
    max_sequence_length = 130

    def __init__(self, audio_folder):
        self.audio_folder = audio_folder
        self.file_list = self.generate_file_list()

    def generate_file_list(self):
        file_list = []
        for root, directories, files in os.walk(self.audio_folder):
            print([os.remove(self.audio_folder+"/"+file) for file in files if ".h5" in file and h5.File(self.audio_folder+"/"+file, "r")["features/spectrum"].shape[0] <= DataSet.min_sequence_length])
            file_list += [(file, h5.File(self.audio_folder+"/"+file, "r")["features/spectrum"].shape[0]) for file in files if ".h5" in file]
        return file_list

    def generate_batch_list(self, batch_size):
        indices = np.random.choice(range(len(self.file_list)), batch_size)
        offsets = [np.random.choice(range(self.file_list[i][1] - (DataSet.min_sequence_length))) for i in indices]
        lengths = [np.random.choice(range(DataSet.min_sequence_length, min(self.file_list[indices[i]][1] - offsets[i], DataSet.max_sequence_length))) for i in xrange(batch_size)]
        return indices, offsets, lengths

    def generate_batch_data(self, batch_size):
        indices, offsets, lengths = self.generate_batch_list(batch_size)

        labels_onset = np.zeros((batch_size, DataSet.max_sequence_length, 1), dtype=int)
        labels_polyphony = np.zeros((batch_size, DataSet.max_sequence_length, 1))
        labels_notes = np.zeros((batch_size, DataSet.max_sequence_length, 1, DataSet.note_label_size))
        features_spectrum = np.zeros((batch_size, DataSet.max_sequence_length, 100))
        features_flux = np.zeros((batch_size, DataSet.max_sequence_length, 100))
        features_peak_locations = np.zeros((batch_size, DataSet.max_sequence_length, 100))
        features_peak_heights = np.zeros((batch_size, DataSet.max_sequence_length, 100))
        feature_lengths = np.zeros((batch_size), dtype=int)

        for i in xrange(batch_size):
            index = indices[i]
            offset = offsets[i]
            length = lengths[i]

            file_name = self.file_list[index][0]
            f = h5.File(self.audio_folder+"/"+file_name, "r")

            labels_onset[i, 0:length, ...] = f["labels/onset"][offset:offset+length, ...][:, np.newaxis, ...]
            labels_polyphony[i, 0:length, ...] = f["labels/polyphony"][offset:offset+length, ...][:, np.newaxis, ...]
            labels_notes[i, 0:length, ...] = f["labels/notes"][offset:offset+length, ...][:, np.newaxis, :, ...]
            features_spectrum[i, 0:length, ...] = f["features/spectrum"][offset:offset+length, ...]
            features_flux[i, 0:length, ...] =  f["features/flux"][offset:offset+length, ...]
            features_peak_locations[i, 0:length, ...] = f["features/peak_locations"][offset:offset+length, ...]
            features_peak_heights[i, 0:length, ...] =  f["features/peak_heights"][offset:offset+length, ...]
            feature_lengths[i, ...] = length

        return labels_onset, labels_polyphony, labels_notes, features_spectrum, features_flux, features_peak_locations, features_peak_heights, feature_lengths

    def next_batch(self, batch_size):
        labels_onset, labels_polyphony, labels_notes, features_spectrum, features_flux, features_peak_locations, features_peak_heights, feature_lengths = self.generate_batch_data(batch_size)

        features = np.concatenate((features_spectrum,
                                   features_flux,
                                   features_peak_locations,
                                   features_peak_heights), axis=2)

        # Labels:
        labels_notes_inverse = 1 - labels_notes
        note_labels = np.concatenate((labels_notes_inverse, labels_notes), axis=2)

        onset_labels_inverse = 1 - labels_onset
        onset_labels = np.concatenate((onset_labels_inverse, labels_onset), axis=2)

        return (features, feature_lengths), (note_labels, labels_polyphony, onset_labels)
