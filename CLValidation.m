//
//  CLValidation.m
//  ceol
//
//  Created by Ben McRedmond on 24/05/2009.
//  Copyright 2009 Ben McRedmond. All rights reserved.
//

#import <stdarg.h>
#import "CLValidation.h"

// Basic Validators
NSString * const CLValidateAlpha = @"validateAlpha:";
NSString * const CLValidateAlphaSpaces = @"validateAlphaSpaces:";
NSString * const CLValidateAlphaNumeric = @"validateAlphanumeric:";
NSString * const CLValidateAlphaNumericDash = @"validateAlphanumericDash:";
NSString * const CLValidateNotEmpty = @"validateNotEmpty:";
NSString * const CLValidateEmail = @"validateEmail:";

// Validations that take second parameters
NSString * const CLValidateMatchesConfirmation = @"validateMatchesConfirmation:";
NSString * const CLValidateMinimumLength = @"validateMinimumLength:";
NSString * const CLValidateCustomAsync = @"asyncValidationMethod:";

@implementation CLValidation

@synthesize delegate;

- (id) init {
    self = [super init];
    
    if(self)
    {
        errorTable = [[NSMutableDictionary alloc] initWithCapacity:7];
        asyncErrorFields = [[NSMutableDictionary alloc] initWithCapacity:1];
        errorStrings = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                            @"Letters only",                        CLValidateAlpha,
                            @"Letters and Spaces Only",             CLValidateAlphaSpaces,
                            @"Letters and Numbers Only",            CLValidateAlphaNumeric,
                            @"Letters, Numbers and Dashes Only",    CLValidateAlphaNumericDash,
                            @"Can't be empty",                      CLValidateNotEmpty,
                            @"Invalid Email Address",               CLValidateEmail, 
                            @"Does not match confirmation",         CLValidateMatchesConfirmation, 
                            @"",                                    CLValidateCustomAsync, nil];
    }
    
    return self;
}

- (id) initWithCustomErrors: (NSDictionary *) errors {
    self = [self init];
    
    if(self)
    {
        [errorStrings release];
        errorStrings = errors;
    }
    
    return self;
}

- (void) dealloc {
    [errorTable release];
    [errorStrings release];
    [asyncErrorFields release];
    [super dealloc];
}

- (NSArray *) validateObject: (id) object tag: (NSString *) tag errorField: (NSTextField *) errorField rules: (NSString * const) firstRule, ... {
    tempErrors = [[NSMutableArray alloc] initWithCapacity:1];

    NSString *nextRule = firstRule;
    currentTag = tag;
    currentErrorField = errorField;
    
    va_list arguments;
    va_start(arguments, firstRule);        
    
    while(nextRule)
    {
        [self validateRule:nextRule candidate:object tag:tag];
        nextRule = va_arg(arguments, NSString * const);
    }

    va_end(arguments);    
    
    [self updateErrorFieldDelegate:errorField withErrors:tempErrors];    
    return [tempErrors autorelease];
}

- (NSArray *) validateObjectWithParamaters: (id) object tag: (NSString *) tag errorField: (NSTextField *) errorField rules: (id) firstRule, ... {
    tempErrors = [[NSMutableArray alloc] initWithCapacity:1];

    id nextObject = firstRule;
    currentTag = tag;
    currentErrorField = errorField;
    
    va_list arguments;
    va_start(arguments, firstRule);
    
    while(nextObject)
    {
        [self validateRuleWithParamater:nextObject candidate:object tag:tag paramater:va_arg(arguments, id)];
        nextObject = va_arg(arguments, id);
    }

    va_end(arguments);
    
    [self updateErrorFieldDelegate:errorField withErrors:tempErrors];    
    return [tempErrors autorelease];
}

- (void) updateErrorFieldDelegate:errorField withErrors:errors {
    // If they've provided an errorField we'll assume they've setup their delegate
    if(errorField)
    {
        [delegate updateErrorField:errorField withErrors:errors];
    }
}

- (void) validateRule: (NSString * const) rule candidate: (id) candidate tag: (NSString *) tag  {
    [self validateRuleWithParamater:rule candidate: candidate tag:tag paramater:nil];
}

- (void) validateRuleWithParamater: (NSString * const) rule candidate: (id) candidate tag: (NSString *) tag paramater: (id) paramater {
    SEL selector = NSSelectorFromString([rule stringByAppendingString:@"paramater:"]);
    BOOL isValid;
    
    // Check if this method takes a paramter
    if([self respondsToSelector:selector])
    {
        isValid = [self performSelector:selector withObject:candidate withObject:paramater];
    }
    else
    {
        selector = NSSelectorFromString(rule);
        isValid = [self performSelector:selector withObject:candidate];
    }
    
    [self modifyErrorTable:tag method:rule isValid:isValid];
    if(!isValid) [tempErrors addObject:[errorStrings objectForKey:rule]];
}

- (void) modifyErrorTable: (NSString *) tag method: (NSString * const) method isValid: (BOOL) isValid {
    // Check whether there's an entry already in the error table
    if([errorTable objectForKey:tag] == nil)
        [errorTable setObject:[NSMutableDictionary dictionaryWithCapacity:1] forKey:tag];
    
    // Update the 'table'
    [[errorTable objectForKey:tag] setObject:[NSNumber numberWithBool:isValid] forKey:method];
}

- (int) errorCount {
    int errors = 0;
    
    NSEnumerator *enumerator = [errorTable objectEnumerator];
    NSEnumerator *innerEnumerator;
    
    // The only objects in our table should be mutable dictionaries
    NSMutableDictionary *value;
    NSNumber *innerValue;    

    while((value = [enumerator nextObject]))
    {
        innerEnumerator = [value objectEnumerator];
        while((innerValue = [innerEnumerator nextObject]))
        {
            if(![innerValue boolValue]) ++errors;
        }
    }
    
    return errors;
}

- (int) errorCountForTag: (NSString *) tag {
    int errors = 0;
    
    NSEnumerator *enumerator = [[errorTable objectForKey:tag] objectEnumerator];
    NSNumber *value;
    
    while((value = [enumerator nextObject]))
    {
        if(![value boolValue]) ++errors;
    }
    
    return errors;
}

- (void) reset {
    [errorTable removeAllObjects];
}

// ======================
// = Validation Methods =
// ======================
- (BOOL) validateAlpha: (NSString *) candidate {
    return [self validateStringInCharacterSet:candidate characterSet:[NSCharacterSet letterCharacterSet]];
}

- (BOOL) validateAlphaSpaces: (NSString *) candidate {
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    [characterSet addCharactersInString:@" "];
    return [self validateStringInCharacterSet:candidate characterSet:characterSet];
}

- (BOOL) validateAlphanumeric: (NSString *) candidate {
    return [self validateStringInCharacterSet:candidate characterSet:[NSCharacterSet alphanumericCharacterSet]];
}

- (BOOL) validateAlphanumericDash: (NSString *) candidate {
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet alphanumericCharacterSet];
    [characterSet addCharactersInString:@"-_."];
    return [self validateStringInCharacterSet:candidate characterSet:characterSet];
}

- (BOOL) validateStringInCharacterSet: (NSString *) string characterSet: (NSMutableCharacterSet *) characterSet {
    // Since we invert the character set if it is == NSNotFound then it is in the character set.
    return ([string rangeOfCharacterFromSet:[characterSet invertedSet]].location != NSNotFound) ? NO : YES;
}

- (BOOL) validateNotEmpty: (NSString *) candidate {
    return ([candidate length] == 0) ? NO : YES;
}

- (BOOL) validateEmail: (NSString *) candidate {
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"; 
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex]; 

    return [emailTest evaluateWithObject:candidate];
}

- (BOOL) validateMatchesConfirmation: (NSString *) candidate paramater: (NSString *) confirmation {
    return [candidate isEqualToString:confirmation];
}

- (BOOL) validateMinimumLength: (NSString *) candidate paramater: (int) length {
    [errorStrings setObject:[NSString stringWithFormat:@"Not longer than %d characters", length] forKey:CLValidateMinimumLength];
    return ([candidate length] >= length) ? YES : NO;
}

// This is to allow thing like making a web request to make a validation
// For example to check if a username is available.
- (void) asyncValidationMethod: (id) candidate paramater: (NSArray *) objectAndSelectorString {
    // Make us the delegate of this class, so we get the response
    [[objectAndSelectorString objectAtIndex:0] setDelegate:self];
    [[objectAndSelectorString objectAtIndex:0] performSelector:NSSelectorFromString([objectAndSelectorString objectAtIndex:1]) withObject:candidate withObject:currentTag]; 
    [asyncErrorFields setObject:currentErrorField forKey:currentTag];
}

- (void) asyncValidationMethodComplete: (NSString *) tag isValid: (BOOL) isValid error: (NSString *) error {
    if(!isValid) [delegate updateErrorField:[asyncErrorFields objectForKey:tag] withErrors:[NSArray arrayWithObject:error]];
    [self modifyErrorTable:tag method:CLValidateCustomAsync isValid:isValid];
    [asyncErrorFields removeObjectForKey:tag];
}

@end
