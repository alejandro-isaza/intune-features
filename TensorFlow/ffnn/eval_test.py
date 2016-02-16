import tensorflow as tf
import net

if __name__ == "__main__":
    labels = tf.constant([[0, 3, 4, 0, 2, 4, 5, 6],
                          [9, 2, 5, 3, 7, 9, 4, 7]])
    logits = tf.constant([[0, 1, 1, 0, 0, 1, 1, 1],
                          [2, 1, 5, 0, 6, 7, 3, 7]])

    init = tf.initialize_all_variables()

    # Launch the graph.
    sess = tf.Session()
    sess.run(init)

    with sess.as_default():
        assert net.evaluation(logits, labels).eval() == 4.5
