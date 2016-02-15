import h5py as h5
import numpy as np

import os


class DataSet:
    feature_size = 400
    polyphony_label_size = 7
    note_label_size = 88
    onset_label_size = 2
    step_size = 1024

    def __init__(self, audio_folder):
        self.audio_folder = audio_folder
        self.file_list = generate_file_list()

    def generate_file_list():
        file_list = []
        for root, directories, files in os.walk(self.audio_folder):
            file_list += [(file, h5.File(file, "r")["features/spectrum"].shape[0]) for file in files if ".h5" in file]
        return file_list

    def generate_batch_list(self, batch_size):
        indices = np.random.choice(range(len(self.file_list)), batch_size)
        offsets = [np.random.choice(range(offset)) for _, offset in self.file_list]
        lengths = [np.random.choice(self.file_list[i][1] - offsets[i]) for i in indices]
        return indices, offsets, lengths

    def generate_batch_data(self, batch_size):
        labels_onset = np.array()
        labels_polyphony = np.array()
        labels_notes = np.array()
        features_spectrum = np.array()
        features_flux = np.array()
        features_peak_locations = np.array()
        features_peak_heights = np.array()
        feature_lengths = np.array()

        for index, offset, length in generate_batch_list(batch_size):
            file_name = self.file_list[index][0]
            f = h5.File(file_name, "r")

            labels_onset.append(f["labels/onset"][np.newaxis, offset:offset+length, ...])
            labels_polyphony.append(f["labels/polyphony"][np.newaxis, offset:offset+length, ...])
            labels_notes.append(f["labels/notes"][np.newaxis, offset:offset+length, np.newaxis, ...])
            features_spectrum.append(f["features/spectrum"][np.newaxis, offset:offset+length, ...])
            features_flux.append(f["features/flux"][np.newaxis, offset:offset+length, ...])
            features_peak_locations.append(f["features/peak_locations"][np.newaxis, offset:offset+length, ...])
            features_peak_heights.append(f["features/peak_heights"][np.newaxis, offset:offset+length, ...])
            feature_lengths.append(length)

        return labels_onset, labels_polyphony, labels_notes, features_spectrum, features_flux, features_peak_locations, features_peak_heights, feature_lengths

    def next_batch(self, batch_size):
        if (self.present_index + batch_size > self.sample_count):
            self.present_index = 0

        labels_onset, labels_polyphony, labels_notes, features_spectrum, features_flux, features_peak_locations, features_peak_heights, feature_lengths = generate_batch_data(batch_size)

        features = np.concatenate((features_spectrum,
                                   features_flux,
                                   features_peak_locations,
                                   features_peak_heights), axis=2)

        # Labels:
        labels_notes_inverse = 1 - labels_notes
        note_labels = np.concatenate((labels_notes_inverse, labels_notes), axis=2)

        polyphony_labels = np.eye(DataSet.polyphony_label_size)[labels_polyphony]

        onset_labels_inverse = 1 - labels_onset
        onset_labels = np.concatenate((onset_labels_inverse, labels_onset), axis=2)

        return (features, feature_lengths), (note_labels, polyphony_labels, onset_labels)
