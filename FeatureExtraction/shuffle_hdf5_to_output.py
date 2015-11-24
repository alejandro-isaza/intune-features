import sys
from random import shuffle

import h5py as h5


block_size = 1000
out_index = 0

def exchange(in_data, out_data, out_index, indices):
        for i in indices:
            out_data[out_index, ...] = in_data[i, ...]
            out_index += 1

in_file = h5.File(sys.argv[1], 'r+')
out_file = h5.File(sys.argv[2], 'w')

for dataset in in_file.keys():
    in_data = in_file[dataset]
    out_data = out_file.create_dataset(dataset, shape=in_data.shape)
    out_index = 0

    unshuffled = range(in_data.shape[0])
    shuffle(unshuffled)

    while len(unshuffled) > block_size:
        print "{0} of {1}".format(len(unshuffled), in_data.shape[0])

        random_indices = unshuffled[:block_size]
        exchange(in_data, out_data, out_index, random_indices)
        unshuffled = unshuffles[block_size:]

    exchange(in_data, out_data, out_index, unshuffled)
