/*
 * Created by Martin Carlberg on Juli 18, 2012.
 * Copyright 2012, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "LOJSKeyedArchiver.j"
@import "LOFetchSpecification.j"
@import "LOObjectStore.j"


@implementation LOLocalDictionaryObjectStore : LOObjectStore {
    CPMutableDictionary     objectFixture @accessors;
}

- (id)init {
    self = [super init];
    if (self) {
        objectFixture = [CPMutableDictionary dictionary];
    }
    return self;
}

- (CPArray) _fetchAndFilterObjects:(LOFFetchSpecification) fetchSpecification  objectContext:(LOObjectContext)objectContext {
    //print(_cmd + " entity:" + [fetchSpecification entityName] + " oper: " + [fetchSpecification operator] + " qualifier:" + [fetchSpecification qualifier]);
    var fixtureObjects = [objectFixture objectForKey:[fetchSpecification entityName]];
    var predicate = [fetchSpecification qualifier];
    if (predicate) {
        fixtureObjects = [fixtureObjects filteredArrayUsingPredicate:predicate];
    }

    var objects = [];
    var registeredObjects = [CPMutableDictionary dictionary];

    var possibleToOneFaultObjects =[CPMutableArray array];

    for (var i=0; i<[fixtureObjects count]; i++) {
        var object = [fixtureObjects objectAtIndex:i];

        var objectUuid = [object valueForKey:@"key"];
        var objectType = [objectContext typeOfObject:object];
        var newObject = [registeredObjects objectForKey:objectUuid];
        if (!newObject) {
            var newObject = [objectContext newObjectForType:objectType];
            if (newObject) {
                [newObject setValue:objectUuid forKey:@"key"];
                [registeredObjects setObject:newObject forKey:objectUuid];
            }
        }
        if (!newObject) continue;

        var attributeKeys = [self attributeKeysForObject:newObject];
        for (var j=0; j<[attributeKeys count]; j++) {
            var key = [attributeKeys objectAtIndex:j];
            var value = [object valueForKey:key];
            if ([key hasSuffix:@"_fk"]) {    // Handle to one relationship
                key = [key substringToIndex:[key length] - 3]; // Remove "_fk" at end
                if (value) {
                    var toOne = [objectContext objectForGlobalId:value];
                    if (toOne) {
                        value = toOne;
                    } else {
                        // Add it to a list and try again after we have registered all objects.
                        [possibleToOneFaultObjects addObject:{@"object":object , @"relationshipKey":key , @"globalId":value}];
                        value = nil;
                    }
                }
            }
            [newObject setValue:value forKey:key];
        }

        [objects addObject:newObject];
    }

    var size = [possibleToOneFaultObjects count];
    for (var i = 0; i < size; i++) {
        var possibleToOneFaultObject = [possibleToOneFaultObjects objectAtIndex:i];
        var toOne = [registeredObjects objectForKey:possibleToOneFaultObject.globalId];
        if (toOne) {
            [possibleToOneFaultObject.object setValue:toOne forKey:possibleToOneFaultObject.relationshipKey];
        } else {
            //console.log([self className] + " " + _cmd + " Can't find object for toOne relationship '" + possibleToOneFaultObject.relationshipKey + "' (" + toOne + ") on object " + possibleToOneFaultObject.object);
            //print([self className] + " " + _cmd + " Can't find object for toOne relationship '" + possibleToOneFaultObject.relationshipKey + "' (" + toOne + ") on object " + possibleToOneFaultObject.object);
        }
    }

    return objects;
}

/*!
 * Must call [objectContext objectsReceived: withFetchSpecification:] when objects are received
 */
- (CPArray) requestObjectsWithFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
    var objects = [self _fetchAndFilterObjects:fetchSpecification objectContext:objectContext];
    [objectContext objectsReceived:objects withFetchSpecification:fetchSpecification];
}

/*!
 * Must call [objectContext faultReceived:(CPArray)objectList withFetchSpecification:(LOFetchSpecification)fetchSpecification faultArray:(LOFaultArray)faultArray] when fault objects are received
 */
- (CPArray) requestFaultArray:(LOFaultArray)faultArray withFetchSpecification:(LOFFetchSpecification) fetchSpecification objectContext:(LOObjectContext) objectContext {
    var objects = [self _fetchAndFilterObjects:fetchSpecification objectContext:objectContext];
    [objectContext faultReceived:objects withFetchSpecification:fetchSpecification faultArray:faultArray];
}

/*!
 * This method should save all changes to the backend.
 * The ObjectContext has a list of LOModifyRecord that contains all changes.
 * Must call [objectContext saveChangesDidComplete] when done
 */
- (void) saveChangesWithObjectContext:(LOObjectContext) objectContext {
    [objectContext saveChangesDidComplete];
}

/*!
 * Must return an array with keys for all attributes for this object.
 * The objectContext will observe all these attributes for changes and record them.
 */
- (CPArray) attributeKeysForObject:(id) theObject {
    return [theObject allKeys];
}

/*!
 * Returns the type of the object
 */
- (CPString) typeOfObject:(id) theObject {
    return [theObject objectForKey:@"entity"];
}

/*!
 * Returns a unique id for the object
 */
- (CPString) globalIdForObject:(id) theObject {
    return [theObject UID];
}

@end
