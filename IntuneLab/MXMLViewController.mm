//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#import "MXMLViewController.h"
#import "IntuneLab-Swift.h"

#include <lxml/lxml.h>
#include <mxml/EventFactory.h>
#include <mxml/ScoreProperties.h>
#include <mxml/dom/Note.h>
#include <mxml/parsing/ScoreHandler.h>

#include <fstream>
#include <map>

typedef unsigned int MidiNumber;

@interface MXMLViewController ()

@property(nonatomic, strong) VMPianoRollViewController *pianoRollViewController;

@end

@implementation MXMLViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    std::unique_ptr<mxml::dom::Score> score = [self loadScore:@"kiss_the_rain"];
    NSArray* eventRects = [self createEventRectsFromScore:*score];

    _pianoRollViewController = [VMPianoRollViewController createWithEventRects:eventRects];
    [self addChildViewController:_pianoRollViewController];
    _pianoRollViewController.view.frame = self.view.bounds;
    [self.view addSubview:_pianoRollViewController.view];
    [_pianoRollViewController didMoveToParentViewController:self];
}

- (std::unique_ptr<mxml::dom::Score>)loadScore:(NSString *)name {
    NSString* path = [[NSBundle mainBundle] pathForResource:[@"XML" stringByAppendingPathComponent:name] ofType:@"xml"];
    mxml::parsing::ScoreHandler handler;
    std::ifstream is([path UTF8String]);
    lxml::parse(is, [path UTF8String], handler);
    return handler.result();
}

- (NSArray*)createEventRectsFromScore:(const mxml::dom::Score&)score {
    NSMutableArray* eventRects = [NSMutableArray array];

    mxml::ScoreProperties scoreProperties(score);
    mxml::EventFactory eventFactory(score, scoreProperties);
    std::unique_ptr<mxml::EventSequence> eventSequence = eventFactory.build();

    std::map<MidiNumber, std::pair<int, float>> onNotesWallTime;
    for (auto& event : eventSequence->events()) {

        for (auto& onNote : event.onNotes()) {
            if (onNote->rest)
                continue;

            MidiNumber midiNumber = onNote->midiNumber();
            auto& element = onNotesWallTime[midiNumber];
            if (element.first == 0) {
                element = {1, event.wallTime()};
            } else {
                element.first += 1;
            }
        }

        for (auto& offNote : event.offNotes()) {
            if (offNote->rest)
                continue;

            MidiNumber midiNumber = offNote->midiNumber();
            auto& element = onNotesWallTime[midiNumber];
            element.first -= 1;
            if (element.first == 0) {
                auto noteStartTime = element.second;
                auto noteEndTime = event.wallTime();

                CGRect noteRect = CGRectMake(midiNumber, noteStartTime, 1, noteEndTime - noteStartTime);
                NSValue *noteRectValue = [NSValue  valueWithCGRect:noteRect];
                [eventRects addObject:noteRectValue];
            }
        }
    }

    return eventRects;
}

@end
