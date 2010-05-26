/* 
 * Copyright (C) 2010  James Stapleton
 *
 * This file is part of Iphone PasswordMaker.
 *
 * Iphone PasswordMaker is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Iphone PasswordMaker is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License
 * along with Iphone PasswordMaker.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "PasswordMakerAppDelegate.h"
#import "RootViewController.h"
#import "Hasher.h"


@implementation PasswordMakerAppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize charSetNames ;

#pragma mark -
#pragma mark Application lifecycle


- (void)applicationDidFinishLaunching:(UIApplication *)application {    
	
	NSDictionary* defaults = [NSDictionary dictionaryWithContentsOfFile:
				 [[NSBundle mainBundle] 
				  pathForResource:@"Defaults" ofType:@"plist"]] ;
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults ] ;
	NSString* profileName = [[NSUserDefaults standardUserDefaults] objectForKey:@"profileName"] ;
	profileList = [[NSMutableArray alloc] initWithCapacity:2] ;
	[profileList addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"profiles"]];
	[self loadHasherProfile:profileName] ;
	
	self.charSetNames = [NSDictionary dictionaryWithObjectsAndKeys:
					 @"A-Za-z0-9Syms", ALPANUMSYM, 
					 @"A-Za-z0-9", ALPHANUM, 
					 @"0-9a-f", HEXS,
					 @"0-9", NUMS,
					 @"A-Za-z", LETTERS,
					 @"Symbols", SYMS,
					 nil ] ;
	
	rootViewController = [[RootViewController alloc] initWithHasher:hasher] ;
	navigationController = [[UINavigationController alloc] 
							initWithRootViewController:rootViewController];
	self.navigationController = navigationController ;
	[window addSubview:[navigationController view]];
    [window makeKeyAndVisible];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[self saveHasherProfile] ;
	[[NSUserDefaults standardUserDefaults] setObject:profileList forKey:@"profiles"] ;
	[rootViewController applicationWillTerminate:application] ;
	[rootViewController.view removeFromSuperview] ;
	[rootViewController release] ;
	[charSetNames release] ;
	[hasher release] ;
	hasher = nil ;
}

#pragma mark -

#pragma mark Hasher Profiles

@synthesize profileList ;

- (void) addProfile:(NSString*)str {
	if ( !str || [str isEqualToString:@""] || [str isEqualToString:@"__default__"] ) return ;
	// only add if not already exist
	if ( [profileList indexOfObject:str] == NSNotFound )
		[profileList addObject:str] ;
}

- (void) remProfile:(NSString*)profileName {
	if ( [profileName isEqualToString:@"__default__"] ) return ;
	[profileList removeObject:profileName] ;
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSString* myPath = [[NSBundle mainBundle] pathForResource:profileName ofType:@"profplist"] ;
	if ( myPath ) {
		NSError* error ;
		[fileManager removeItemAtPath:myPath error:&error];
		if ( error ) {
			NSLog(@"Error removing profile: %@", error ) ;
		}
	}
}



- (void) loadHasherProfile:(NSString*)profileName {
	if ( hasher ) 
		[self saveHasherProfile] ;
	else {
		hasher = [[Hasher alloc] init] ;
	}
	if ( ! profileName || [profileName length] == 0 ) {
		profileName = @"__default__" ;	
		hasher.profileName = @"" ;
	} else {
		hasher.profileName = profileName ;
		profileName = [@"_p" stringByAppendingString:profileName] ;
	}
	// use profplist because plist is used for defaults, don't want user to overwrite that on 
	// accident.
	NSDictionary* dict = [[NSUserDefaults standardUserDefaults] objectForKey:profileName];
	
	if ( dict ) {
		hasher.hashAlgo = [dict objectForKey:@"HashAlgo"] ;
		hasher.maxLen = [ (NSNumber*)[dict objectForKey:@"PassLength"] integerValue] ;
		hasher.counter = [dict objectForKey:@"modifier"] ;
		hasher.prefix = [dict objectForKey:@"prefix"] ;
		hasher.suffix = [dict objectForKey:@"suffix"] ;
		hasher.characters = [dict objectForKey:@"characters"] ;
		hasher.leetSpeak = [self leetTypeFromSettingString:[dict objectForKey:@"leetType"] ] ;
		hasher.leetLevel = [ (NSNumber*) [dict objectForKey:@"leetLevel"] integerValue ] ;
		hasher.savedPasswordHash = [dict objectForKey:@"savedPasswordHash"] ;
	} else {
		[self saveHasherProfile] ;
	}
}

- (void) saveHasherProfile {
	NSString* profName = hasher.profileName ;
	if ( [profName length] == 0 ) {
		profName = @"__default__" ;
		[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"profileName"] ;	
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:hasher.profileName forKey:@"profileName"] ;	
		profName = [@"_p" stringByAppendingString:profName] ;
	}
	NSDictionary* dict = [[NSMutableDictionary alloc] init] ;
	[dict setValue:hasher.hashAlgo forKey:@"HashAlgo"] ;
	[dict setValue:[NSNumber numberWithInteger:hasher.maxLen] forKey:@"PassLength"] ;
	[dict setValue:hasher.counter forKey:@"modifier"] ;
	[dict setValue:hasher.prefix forKey:@"prefix"] ;
	[dict setValue:hasher.suffix forKey:@"suffix"] ;
	[dict setValue:hasher.characters forKey:@"characters"] ;
	[dict setValue:[self settingStringFromLeetType:hasher.leetSpeak] forKey:@"leetType"] ;
	[dict setValue:[NSNumber numberWithInteger:hasher.leetLevel] forKey:@"leetLevel"] ;
	[dict setValue:hasher.savedPasswordHash forKey:@"savedPasswordHash"] ;
	[[NSUserDefaults standardUserDefaults] setObject:dict forKey:profName] ;
	[dict release] ;
	[self addProfile:hasher.profileName] ;
	[[NSUserDefaults standardUserDefaults] setObject:hasher.profileName forKey:@"profileName"] ;
}

- (NSDictionary *)parseQueryString:(NSString *)query {
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [dict setObject:val forKey:key];
    }
    return dict;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
	// Recover the string
    if (!url) return NO ;
	
	if ( ! [url.host isEqualToString:@"getpassword"] )
		return NO ;
	
	NSDictionary* arguments = [self parseQueryString:url.query] ;
	NSString* target_url = [arguments objectForKey:@"url"] ;
	rootViewController.inputURLText = target_url ;
	return YES ;
}

- (BOOL) matchesSavedPassword:(NSString*)password {
	if( hasher.savedPasswordHash ) {
		NSString* newHash = [hasher generatePasswordWithMasterPassword:password 
																   Url:@"__master_password__" 
															  Username:@"123876"] ;
		return [newHash compare:hasher.savedPasswordHash] == NSOrderedSame;
	}
	return NO ;
}

- (void) setNewMasterPassword:(NSString*)password {
	hasher.savedPasswordHash = [hasher generatePasswordWithMasterPassword:password
																	  Url:@"__master_password__" 
																 Username:@"123876"] ;
}


#pragma mark LeetType Conversions
- (enum leetType) leetTypeFromSettingString:(NSString*)str {
	if ( [str isEqualToString:@"NONE" ] )
		return LEET_NONE ;
	else if ( [str isEqualToString:@"BEFORE"] )
		return LEET_BEFORE ;
	else if ( [str isEqualToString:@"AFTER"] )
		return LEET_AFTER ;
	else if ( [str isEqualToString:@"BOTH"] )
		return LEET_BOTH ;
	return LEET_NONE ;
}

- (NSString*) settingStringFromLeetType:(enum leetType)lt {
	switch (lt) {
		case LEET_BEFORE:
			return @"BEFORE";
		case LEET_AFTER:
			return @"AFTER" ;
		case LEET_BOTH:
			return @"BOTH";
		case LEET_NONE:
		default:
			return @"NONE" ;
	};
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc {
	[profileList release] ;
	[hasher release] ;
	[navigationController release];
	[window release];
	[super dealloc];
}


@end

