/*
 * LOArrayController.j
 *
 * Created by Martin Carlberg on Feb 27, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import <AppKit/CPArrayController.j>

@implementation LOArrayController : CPArrayController
{
    @outlet LOObjectContext objectContext;
}

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

// TODO: We should advertise a 'real' binding for objectContext, not piggyback on managedObjectContext.
- (void)setManagedObjectContext:(id)aContext {
    objectContext = aContext;
}

// TODO: We should advertise a 'real' binding for objectContext, not piggyback on managedObjectContext.
- (id)managedObjectContext {
    return objectContext;
}

- (@action)insert:(id)sender {
    if (![self canInsert])
        return;
    
    var newObject = [self automaticallyPreparesContent] ? [self newObject] : [self _defaultNewObject];
    [self insertObject:newObject];
}

- (void)insertObject:(id)newObject {
    if (![self canInsert])
        return;

    [self addObject:newObject];
    [self setSelectedObjects:[newObject]];

    // Ok, now we need to tell the object context that we have this new object and it is a new relationship for the owner object.
    // This might not be the best way to do this but it will do for now.
    var info = [self infoForBinding:@"contentArray"];
    var bindingKeyPath = [info objectForKey:CPObservedKeyPathKey];
    var keyPathComponents = [bindingKeyPath componentsSeparatedByString:@"."];
    var lastbindingKeyPath = [keyPathComponents objectAtIndex:[keyPathComponents count] - 1];
    var bindToObject = [info objectForKey:CPObservedObjectKey];
    var selectedOwnerObjects = [bindToObject selectedObjects];
    var registeredOwnerObjects = [CPMutableArray array];
    var selectedOwnerObjectsSize = [selectedOwnerObjects count];
    for (var i = 0; i < selectedOwnerObjectsSize; i++) {
        var selectedOwnerObject = [selectedOwnerObjects objectAtIndex:i];
        if ([objectContext isObjectRegistered:selectedOwnerObject]) {
            [registeredOwnerObjects addObject:selectedOwnerObject];
            [objectContext _add:newObject toRelationshipWithKey:lastbindingKeyPath forObject:selectedOwnerObject];
        }
    }

    var insertEvent = [LOInsertEvent insertEventWithObject:newObject arrayController:self ownerObjects:[registeredOwnerObjects count] ? registeredOwnerObjects : nil ownerRelationshipKey:lastbindingKeyPath];
    [objectContext registerEvent:insertEvent];
    [objectContext _insertObject:newObject];
    if ([objectContext autoCommit]) [objectContext saveChanges];
}

- (id) unInsertObject:(id)object ownerObjects:(CPArray) ownerObjects ownerRelationshipKey:(CPString) ownerRelationshipKey {
    [self _removeObjects:[object]];
    if (ownerObjects && ownerRelationshipKey) {
        var size = [ownerObjects count];
        for (var i = 0; i < size; i++) {
            var ownerObject = [ownerObjects objectAtIndex:i];
            [objectContext _unAdd:object toRelationshipWithKey:ownerRelationshipKey forObject:ownerObject];
        }
    }
}

- (void)removeObjects:(CPArray)objectsToDelete {
    var objectsToDeleteIndexes = [CPMutableIndexSet indexSet];
    [objectsToDelete enumerateObjectsUsingBlock:function(aCandidate) {
        var anIndex = [[self arrangedObjects] indexOfObjectIdenticalTo:aCandidate];
        if (anIndex === CPNotFound) {
            [CPException raise:CPInvalidArgumentException reason:@"Can't delete object not in array controller: " + aCandidate];
        }
        [objectsToDeleteIndexes addIndex:anIndex];
    }];
    [self _removeObjects:objectsToDelete atIndexes:objectsToDeleteIndexes shouldRegisterEvent:YES];
}

- (void)_removeObjects:(CPArray)objectsToDelete {
    var objectsToDeleteIndexes = [CPMutableIndexSet indexSet];
    [objectsToDelete enumerateObjectsUsingBlock:function(aCandidate) {
        var anIndex = [[self arrangedObjects] indexOfObjectIdenticalTo:aCandidate];
        if (anIndex === CPNotFound) {
            [CPException raise:CPInvalidArgumentException reason:@"Can't delete object not in array controller: " + aCandidate];
        }
        [objectsToDeleteIndexes addIndex:anIndex];
    }];
    [self _removeObjects:objectsToDelete atIndexes:objectsToDeleteIndexes shouldRegisterEvent:NO];
}

- (void)remove:(id)sender {
    var selectedObjectsIndexes = [[self selectionIndexes] copy];
    var selectedObjects = [self selectedObjects];
    [self _removeObjects:selectedObjects atIndexes:selectedObjectsIndexes shouldRegisterEvent:YES];
}

- (void)_removeObjects:(CPArray)objectsToDelete atIndexes:(CPIndexSet)objectsToDeleteIndexes shouldRegisterEvent:(BOOL)shouldRegisterEvent {
    // Note: assumes objectsToDeleteIndexes corresponds to objectsToDelete.
    [self removeObjectsAtArrangedObjectIndexes:objectsToDeleteIndexes];
    // Ok, now we need to tell the object context that we have this removed object and it is a removed relationship for the owner object.
    // This might not be the best way to do this but it will do for now.
    var registeredOwnerObjects = [CPMutableArray array];
    var lastbindingKeyPath = nil;
    [objectsToDelete enumerateObjectsUsingBlock:function(deletedObject) {
        var info = [self infoForBinding:@"contentArray"];
        var bindingKeyPath = [info objectForKey:CPObservedKeyPathKey];
        var keyPathComponents = [bindingKeyPath componentsSeparatedByString:@"."];
        lastbindingKeyPath = [keyPathComponents objectAtIndex:[keyPathComponents count] - 1];
        var bindToObject = [info objectForKey:CPObservedObjectKey];
        [[bindToObject selectedObjects] enumerateObjectsUsingBlock:function(selectedOwnerObject) {
            if ([objectContext isObjectRegistered:selectedOwnerObject]) {
                [registeredOwnerObjects addObject:selectedOwnerObject];
                [objectContext _delete:deletedObject withRelationshipWithKey:lastbindingKeyPath forObject:selectedOwnerObject];
            }
        }];
    }];

    if (shouldRegisterEvent) {
        var deleteEvent = [LODeleteEvent deleteEventWithObjects:objectsToDelete atArrangedObjectIndexes:objectsToDeleteIndexes arrayController:self ownerObjects:[registeredOwnerObjects count] ? registeredOwnerObjects : nil ownerRelationshipKey:lastbindingKeyPath];
        [objectContext registerEvent:deleteEvent];
        [objectContext deleteObjects: objectsToDelete]; // this will commit if auto commit is enabled
    }
}

- (id) unDeleteObjects:(id)objects atArrangedObjectIndexes:(CPIndexSet)indexSet ownerObjects:(CPArray) ownerObjects ownerRelationshipKey:(CPString) ownerRelationshipKey {
    var objectSize = [objects count];
    var index = [indexSet firstIndex];
    for (var i = 0; i < objectSize; i++) {
        var object = [objects objectAtIndex:i];
        [self insertObject:object atArrangedObjectIndex:index];
        if (ownerObjects && ownerRelationshipKey) {
            var size = [ownerObjects count];
            for (var j = 0; j < size; j++) {
                var ownerObject = [ownerObjects objectAtIndex:j];
                [objectContext _unAdd:object toRelationshipWithKey:ownerRelationshipKey forObject:ownerObject];
            }
        }
        index = [indexSet indexGreaterThanIndex:index];
    }
}

/*
- (CPArray) arrangeObjects: (CPArray) objects {
    var testArray = [[_CPKVCArray alloc] init];
    var testArrayCopy = [testArray copy];
    //CPLog.trace(@"tracing: arrangeObjects: class = " + [objects class]);
    if ([objects className] === @"_CPKVCArray") {
        debugger;
    }
    var copy = [objects copy];
    //CPLog.trace(@"tracing: arrangeObjects: " + [CPString JSONFromObject:copy]);
    [super arrangeObjects:objects];
}
*/
@end