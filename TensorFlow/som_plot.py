import h5py
import numpy

def notes(label):
    """ Converts from a one-hot array to an array of note values """
    indexes = numpy.arange(label.shape[0])
    return indexes[label.nonzero()]

def octave(note):
    return (note - 12) / 12

h5file = h5py.File('som.h5', 'r')
labels = h5file['on_label']
som = h5file['som']
grid = numpy.zeros((20, 20))

count = labels.shape[0]
for step in xrange(count):
    label = labels[step]
    location = som[step]

