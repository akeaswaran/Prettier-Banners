#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <QuartzCore/QuartzCore.h>
#import "interfaces.h"
#import "substrate.h"

static NSArray *getABPersons()
{
	CFErrorRef error;
	NSArray *persons = nil;
	
	ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
	if(!addressBook) {
		NSLog(@"AddressBook creation error: %@\nContact mootjeuh@outlook.com with a copy of this log.", error);
	} else {
		persons = (__bridge NSArray*)ABAddressBookCopyArrayOfAllPeople(addressBook);
	}
	
	return persons;
}

static UIImage *getABPersonImage(ABRecordRef person)
{
	return ABPersonHasImageData(person) ? [UIImage imageWithData:(__bridge NSData*)ABPersonCopyImageData(person)] : nil;
}

static ABRecordRef getPersonFromBulletin(BBBulletin *bulletin)
{
	ABRecordRef person = nil;
	
	for(id entry in getABPersons()) {
		if(ABRecordGetRecordID((__bridge ABRecordRef)entry) == MSHookIvar<int>(bulletin, "_addressBookRecordID")) {
			person = (__bridge ABRecordRef)entry;
			break;
		}
	}
	
	return person;
}

static UIImage* croppedIconImage(UIImage *image) {
   UIImage * chosenImage = image;

   CGFloat imageWidth  = chosenImage.size.width;
   CGFloat imageHeight = chosenImage.size.height;

   CGRect cropRect;

   cropRect = CGRectMake ((imageHeight - imageWidth) / 2.0, 0.0, imageWidth, imageWidth);

   // Draw new image in current graphics context
   CGImageRef imageRef = CGImageCreateWithImageInRect ([chosenImage CGImage], cropRect);

   // Create new cropped UIImage
   UIImage * croppedImage = [UIImage imageWithCGImage: imageRef scale: chosenImage.scale orientation: chosenImage.imageOrientation];

   CGImageRelease (imageRef);

   UIGraphicsBeginImageContextWithOptions(croppedImage.size, NO, 0.0);   //  <= notice 0.0 as third scale parameter. It is important cause default draw scale ≠ 1.0. Try 1.0 - it will draw an ugly image..
   CGFloat cornerRadius = croppedImage.size.height / 2;
   CGRect bounds=(CGRect){CGPointZero,croppedImage.size};
   [[UIBezierPath bezierPathWithRoundedRect:bounds
                                cornerRadius:cornerRadius] addClip];
   [image drawInRect:bounds];
   UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
   UIGraphicsEndImageContext();

   return finalImage;
}

%hook SBBulletinBannerItem

- (UIImage*)iconImage
{
	UIImage *image = %orig;
	ABRecordRef person = getPersonFromBulletin([self seedBulletin]);
	if(person) {
		image = getABPersonImage(person) ? : image;
	}
	return croppedIconImage(image);
}

- (NSString*)title
{
	NSMutableArray *names = nil;
	NSString *title = %orig;
	NSDictionary *assistantContext = [NSDictionary dictionaryWithDictionary:[self seedBulletin].context[@"AssistantContext"]];
	
	if([[assistantContext allKeys] containsObject:@"msgRecipients"]) {
		NSArray *msgRecipients = [NSArray arrayWithArray:assistantContext[@"msgRecipients"]];
		names = [NSMutableArray array];
		for(NSDictionary *entry in msgRecipients) {
			NSDictionary *object = [NSDictionary dictionaryWithDictionary:entry[@"object"]];
            if([[object allKeys] containsObject:@"firstName"]) {
				[names addObject:object[@"firstName"]];
			} else {
				[names addObject:entry[@"data"]];
			}
		}
	}
	
	if(names) {
		title = [names firstObject];
		for(int i = 1; i < [names count]; i++) {
			title = [NSString stringWithFormat:@"%@, %@", title, names[i]];
		}
	}
	
	return title;
}

%end

%hook SBLockScreenNotificationListView

- (SBLockScreenNotificationCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    SBLockScreenNotificationCell *cell = %orig;
    id item = [(SBLockScreenNotificationListController*)self.nextResponder listItemAtIndexPath:indexPath];
    if([NSStringFromClass([item class]) isEqualToString:@"SBAwayBulletinListItem"]) {
        BBBulletin *bulletin = [item activeBulletin];
		ABRecordRef person = getPersonFromBulletin(bulletin);
		if(person) {
            UIImage *icon = getABPersonImage(person);
            if(icon) {
                cell.icon = croppedIconImage(icon);
            }
		}
    }
    return cell;
}

%end