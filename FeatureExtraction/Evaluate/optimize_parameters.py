from scipy import optimize
import json
from subprocess import call
import argparse

parser = argparse.ArgumentParser(description="Use the results of Evaluate to train its parameters.")
parser.add_argument("-a", "--audio", nargs="?", help="Input audio file.")
parser.add_argument("-m", "--midi", nargs="?", help="Input midi file.")
parser.add_argument("-n", "--network", nargs="?", help="Input network file.")
parser.add_argument("-c", "--config", nargs="?", help="Input config file.")
parser.add_argument("-r", "--ref", nargs="?", help="Input ref file.")
parser.add_argument("-u", "--cursor", nargs="?", help="Input cursor file.")
parser.add_argument("-w", "--weights", nargs="?", default="weights.json", help="Weights json file.")
parser.add_argument("-o", "--output", nargs="?", default="output.txt", help="Output value of Evaluate")
args = parser.parse_args()

weights_file = open(args.weights, "r")
output_file = open(args.output, "r")

weights_json = json.load(weights_file)
onset_trigger = weights_json["onset_trigger"]
onset_height = weights_json["onset_height"]
weights = weights_json["weights"]

bounds = [
            (0, 1),
            (0, 1),
            (0, 2),
            (0, 2),
            (0, 2),
            (0, 2),
            (0, 2),
]

def proxy(array):
    return call_evaluate(array[0], array[1], array[2:])

def call_evaluate(onset_trigger, onset_height, weights):
    weights_json["onset_trigger"] = onset_trigger
    weights_json["onset_height"] = onset_height
    weights_json["weights"] = weights.tolist()
    weights_file = open(args.weights, "w")
    json.dump(weights_json, weights_file)
    weights_file.close()

    call(["Evaluate", "--params", args.weights,
                      "--output", args.output,
                      "--audio", args.audio,
                      "--midi", args.midi,
                      "--network", args.network,
                      "--config", args.config,
                      "--ref", args.ref,
                      "--cursor", args.cursor])

    output_file = open(args.output, "r")
    score = output_file.readline()
    return 1.0 - float(score)

optimize.minimize(proxy, [onset_trigger, onset_height] + weights, jac=False, bounds=bounds)
