import matplotlib.pyplot as plt

import h5py as h5
import numpy as np
from scipy.optimize import curve_fit
import pydub

import argparse
from math import exp, pow, sqrt, pi
import os
import re

bin_size = lambda n: 10000/n
degree = 20

parser = argparse.ArgumentParser(description="Use the results of statistical_analysis.py to process a target database.")
parser.add_argument("-r", "--root", nargs="?", default="Monophonic", help="Root of monophonic file tree.")
parser.add_argument("-o", "--out", nargs="?", default="note_curves.h5", help="Output h5 file.")
args = parser.parse_args()

of = h5.File(args.out, "w")
od = of.create_dataset("curve_coefficients", shape=(88,3), dtype=float)
ext = ".m4a"
audio_files = []
for path, directories, files in os.walk(args.root):
    if "original" in directories:
        directories.remove("original")
    audio_files += [path+'/'+file for file in files if ext in file]

def gauss(data, a, b, c, d):
    return [a * exp(-1 * pow(datum - b, 2) / (2 * pow(c, 2))) + d for datum in data]

def build_upper_bounds(data, number):
    size = int(bin_size(number))
    out = []
    for i in xrange(data.size / size):
        bin = data[i*size:(i+1)*size]
        out.append(bin.max())
    return np.array(out)

note_data_sum_map = dict()
note_count_map = dict()
for file in audio_files:
    number = int(re.search("(\d+).m4a", file).group(1))
    print(file, number)
    try:
        af = pydub.AudioSegment.from_file(file, format="caf")
    except pydub.exceptions.CouldntDecodeError:
        af = pydub.AudioSegment.from_file(file, format="m4a")
    data = build_upper_bounds(np.absolute(np.array(af.get_array_of_samples(), dtype=float)), number)
    data /= data.max()
    # curve = np.polyfit(time, data, degree)
    # curve = curve_fit(gauss, time, data, p0=(1, 200, 10000, 0), ftol=0.1)

    if number in note_data_sum_map:
        if len(data) < len(note_data_sum_map[number]):
            note_count_map[number][:len(data)] += np.ones(len(data))
            note_data_sum_map[number][:len(data)] += data
        else:
            ones = np.ones(len(data))
            ones[:len(note_count_map[number])] += note_count_map[number]
            note_count_map[number] = ones

            data[:len(note_data_sum_map[number])] += note_data_sum_map[number]
            note_data_sum_map[number] = data
    else:
        note_count_map[number] = np.ones(len(data))
        note_data_sum_map[number] = data

for i in xrange(21, 109):
    mean_data = np.divide(note_data_sum_map[i], note_count_map[i])
    time = [bin_size(i)*x for x in xrange(len(mean_data))]
    curve = curve_fit(gauss, time, mean_data, p0=(1, 200, 10000, 0), ftol=0.01)

    a = curve[0][0] + curve[0][3]
    b = curve[0][1]
    c = -1 / (2 * pow(curve[0][2], 2))
    od[i-21, ...] = [a, b, c]

    #
    # print(curve)
    # xp = np.linspace(0, 6*44100, 6*44100)
    # _ = plt.plot(time, mean_data,".",xp, gauss(xp, curve[0][0], curve[0][1], curve[0][2], curve[0][3]), '-')
    # plt.ylim(0,1)
    # plt.xlim(0,6*44100)
    # plt.show()
