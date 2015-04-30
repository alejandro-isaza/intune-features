//  Copyright (c) 2015 Venture Media. All rights reserved.

#pragma once
#include <mxml/dom/Part.h>
#include <mxml/dom/Score.h>
#include <mxml/dom/Note.h>

namespace util {

inline bool isValidNote(const mxml::dom::Note& note) {
    // Ignore rests
    if (note.rest)
        return false;

    // Ignore voice
    const mxml::dom::Part* part = static_cast<const mxml::dom::Part*>(note.measure()->parent());
    const mxml::dom::Score* score = static_cast<const mxml::dom::Score*>(part->parent());
    if (score->parts().size() > 1 && part == score->parts().at(0).get())
        return false;

    return true;
}

}
