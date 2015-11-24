import sys
from random import shuffle, randrange

import h5py as h5


block_size = 10

def random_index(length):
    return unshuffled[randrange(len(unshuffled) - length)]

def random_block(data, length):
    index = random_index(length)
    return (data[index:index+length, ...], index)

def exchange(data, block1, block2, length):
    indices = range(length)
    shuffle(indices)
    for i in range(length):
        block1[i], block2[indices[i]] = block2[indices[i]], block1[i]

h5_file = h5.File(sys.argv[1], 'r+')

for dataset in h5_file.keys():
    data = h5_file[dataset]
    unshuffled = range(data.shape[0] - block_size)

    while len(unshuffled) > 2 * block_size:
        print "{0} left of {1}".format(len(unshuffled), data.shape[0])

        random_block1, random_index1 = random_block(data, block_size)
        random_block2, random_index2 = random_block(data, block_size)

        exchange(data, random_block1, random_block2, block_size)

        unshuffled = list(set(unshuffled) - (set(range(random_index1, random_index1+block_size)) | set(range(random_index2, random_index2+block_size))))

    random_block1, random_index1 = random_block(data, len(unshuffled)//2)
    random_block2, random_index2 = random_block(data, len(unshuffled)//2)
    exchange(data, random_block1, random_block2, len(unshuffled)//2)
