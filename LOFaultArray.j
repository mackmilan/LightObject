/*
 * Created by Martin Carlberg on Mars 5, 2012.
 * Copyright 2012, All rights reserved.
 */

@import <Foundation/CPArray.j>
@import <Foundation/CPPredicate.j>
@import "LOFault.j"

@class LOEditingContext
@class LOObjectContext
@class LOFetchSpecification
@class CPRelationshipDescription

@implementation LOFaultArray : CPMutableArray <LOFault> {
    LOObjectContext objectContext @accessors;
    id              masterObject @accessors;
    CPString        relationshipKey @accessors;
    BOOL            faultFired @accessors;
    BOOL            faultPopulated @accessors;
    CPArray         array @accessors;
    LOFetchSpecification fetchSpecification;
}
/*
 + (id)alloc {
 //CPLog.trace(@"tracing: LOFaultArray.alloc:");
 var array = [];

 array.isa = self;

 var ivars = class_copyIvarList(self),
 count = ivars.length;

 while (count--)
 array[ivar_getName(ivars[count])] = nil;

 return array;
 }
 */
- (id)initWithObjectContext:(CPObjectContext)anObjectContext masterObject:(id)aMasterObject relationshipKey:(CPString)aRelationshipKey {
    //    CPLog.trace(@"tracing: LOFaultArray.init:");
    self = [super init];
    if (self) {
        faultFired = NO;
        objectContext = anObjectContext;
        masterObject = aMasterObject;
        relationshipKey = aRelationshipKey;
        array = [CPArray array];
    }
    return self;
}

- (id)initWithArray:(CPArray)anArray {
    //    CPLog.trace(@"tracing: LOFaultArray.initWithArray: count = " + [anArray count]);
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithArray:anArray];
    }
    return self;
}

- (id)initWithArray:(CPArray)anArray copyItems:(BOOL)shouldCopyItems {
    //    CPLog.trace(@"tracing: LOFaultArray.initWithArray:copyItems:");
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithArray:anArray copyItems:shouldCopyItems];
    }
    return self;
}
/*
 - (id)initWithObjects:(id)anObject, ... {
 //CPLog.trace(@"tracing: LOFaultArray.initWithObjects:...");
 self = [super initWithObjects:anObject];
 if (self) {
 }
 return self;
 }
 */
- (id)initWithObjects:(CPArray)objects count:(CPUInteger)aCount {
    //    CPLog.trace(@"tracing: LOFaultArray.initWithObjects:count:");
    self = [self init];
    if (self) {
        array = [[CPArray alloc] initWithObjects:objects count:aCount];
    }
    return self;
}

- (id)initWithCapacity:(CPUInteger)aCapacity {
    //    CPLog.trace(@"tracing: LOFaultArray.initWithCapacity:");
    return [super initWithCapacity:aCapacity];
}

- (id)copy {
    var copy = [super copy];
    copy.objectContext = self.objectContext;
    copy.masterObject = self.masterObject;
    copy.relationshipKey = self.relationshipKey;
    copy.faultFired = self.faultFired;
    copy.array = [array copy];
    copy.fetchSpecification = self.fetchSpecification;
    return copy;
}

- (CPUInteger)count {
    [self _requestFaultIfNecessary];
    return [array count];
}

- (id)objectAtIndex:(CPUInteger) anIndex {
    [self _requestFaultIfNecessary];
    return [array objectAtIndex:anIndex];
}

- (void)addObject:(id)anObject {
    [self _requestFaultIfNecessary];
    [array addObject:anObject];
}

- (void)insertObject:(id)anObject atIndex:(CPUInteger)anIndex {
    [self _requestFaultIfNecessary];
    [array insertObject:anObject atIndex:anIndex];
}

- (void)replaceObjectAtIndex:(CPUInteger)anIndex withObject:(id)anObject {
    [self _requestFaultIfNecessary];
    [array replaceObjectAtIndex:anIndex withObject:anObject];
}

- (void)removeLastObject {
    [self _requestFaultIfNecessary];
    [array removeLastObject];
}

- (void)removeObjectAtIndex:(CPUInteger)anIndex {
    [self _requestFaultIfNecessary];
    [array removeObjectAtIndex:anIndex];
}

- (void)removeObject:(id)anObject {
    [self _requestFaultIfNecessary];
    [array removeObject:anObject];
}

- (id)_handleObserverForKeyPath:(CPString)aKeyPath {
    return (@"faultFired" === aKeyPath || @"faultPopulated" === aKeyPath)
}

- (void)addObserver:(id)observer forKeyPath:(CPString)aKeyPath options:(CPKeyValueObservingOptions)options context:(id)context {
    if ([self _handleObserverForKeyPath:aKeyPath]) {
        [[_CPKVOProxy proxyForObject:self] _addObserver:observer forKeyPath:aKeyPath options:options context:context]
    } else {
        [array addObserver:observer forKeyPath:aKeyPath options:options context:context];
    }
}

- (void)removeObserver:(id)observer forKeyPath:(CPString)aKeyPath {
    if ([self _handleObserverForKeyPath:aKeyPath]) {
        [[_CPKVOProxy proxyForObject:self] _removeObserver:observer forKeyPath:aKeyPath];
    } else {
        [array removeObserver:observer forKeyPath:aKeyPath];
    }
}

- (void)setValue:(id)aValue forKey:(CPString)aKey {
    if (@"faultFired" === aKey) {
        [self willChangeValueForKey:aKey];
        faultFired = aValue;
        [self didChangeValueForKey:aKey];
    } else if (@"faultPopulated" === aKey) {
        [self willChangeValueForKey:aKey];
        faultPopulated = aValue;
        [self didChangeValueForKey:aKey];
    } else {
        [super setValue:aValue forKey:aKey];
    }
}

- (id)valueForKey:(CPString)aKey {
    if (@"faultFired" === aKey) {
        return faultFired;
    } else if (@"faultPopulated" === aKey) {
        return faultPopulated;
    }
    return [super valueForKey:aKey];
}

- (void)sortUsingFunction:(Function)aFunction context:(id)aContext {
    [self _requestFaultIfNecessary];
    [array sortUsingFunction:aFunction context:aContext];
}

- (void)sortUsingDescriptors:(CPArray)descriptors {
    [self _requestFaultIfNecessary];
    [array sortUsingDescriptors:descriptors];
}

- (void)makeObjectsPerformSelector:(SEL)aSelector {
    [self _requestFaultIfNecessary];
    [array makeObjectsPerformSelector:aSelector];
}

- (void)_requestFaultIfNecessary {
    if (!faultFired) {
        [self requestFaultWithCompletionHandler:nil];
    }
}

/*!
    Designated method for requesting a fault.
    This is hard coded: The master object has an attribute (relationshipKey) that is used as the entity name (the last character is removed, "attribute:persons -> entity:person) The entity is expected to have a attribute named the type of the master object and ending with _fk (master object type: company -> entity attribute: company_fk)
 */
- (void)requestFaultWithRequestId:(id)aRequestId completionHandler:(Function)aCompletionBlock {
    if (!faultFired) {
        [self setFaultFired:YES];
        faultPopulated = NO;
        var objectStore = [objectContext objectStore];
        var masterObjectType = [objectContext typeOfObject:masterObject];
        var foreignKey = [objectStore foreignKeyAttributeForInversRelationshipWithRelationshipAttribute:relationshipKey withEntityNamed:masterObjectType];
        var destinationEntityName = [objectStore destinationEntityNameForRelationshipKey:relationshipKey withEntityNamed:masterObjectType];
        var qualifier = [CPComparisonPredicate predicateWithLeftExpression:[CPExpression expressionForKeyPath:foreignKey]
                                                           rightExpression:[CPExpression expressionForConstantValue:[objectContext globalIdForObject:masterObject]]
                                                                  modifier:CPDirectPredicateModifier
                                                                      type:CPEqualToPredicateOperatorType
                                                                   options:0];
        fetchSpecification = [LOFetchSpecification fetchSpecificationForEntityNamed:destinationEntityName qualifier:qualifier];
        [objectContext requestFaultArray:self withFetchSpecification:fetchSpecification withRequestId:aRequestId withCompletionHandler:aCompletionBlock];
        [[CPNotificationCenter defaultCenter] postNotificationName:LOFaultDidFireNotification object:masterObject userInfo:[CPDictionary dictionaryWithObjects:[self, fetchSpecification, relationshipKey] forKeys:[LOFaultKey,LOFaultFetchSpecificationKey, LOFaultFetchRelationshipKey]]];
    } else if (aCompletionBlock) {
        if (faultPopulated) {
            aCompletionBlock(self);
        } else {
            [objectStore addCompletionHandler:aCompletionBlock toTriggeredFault:self];
        }
    }
}

/*!
    Convenience method for calling -requestFaultWithRequestId:completionHandler: without requestId.
 */
- (void)requestFaultWithCompletionHandler:(Function)aCompletionBlock {
    [self requestFaultWithRequestId:nil completionHandler:aCompletionBlock];
}

- (void)faultReceivedWithObjects:(CPArray)objectList {
    var faultDidPopulateNotificationObject = masterObject;
    var anArray = [masterObject valueForKey:relationshipKey];

    [objectContext registerObjects:objectList];
    [objectContext awakeFromFetchForObjects:objectList];
    [masterObject willChangeValueForKey:relationshipKey];
    [anArray addObjectsFromArray:objectList];
    [masterObject didChangeValueForKey:relationshipKey];
    [self setFaultPopulated:YES];
}

@end
