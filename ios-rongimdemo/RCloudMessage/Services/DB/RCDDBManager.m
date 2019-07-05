//
//  RCDDBManager.m
//  SealTalk
//
//  Created by LiFei on 2019/5/31.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RCDDBManager.h"
#import "RCDDBHelper.h"

static NSString *const USER_TABLE = @"t_user";
static NSString *const GROUP_TABLE = @"t_group";
static NSString *const MY_GROUP_TABLE = @"t_my_group";
static NSString *const GROUP_MEMBER_TABLE = @"t_group_member";
static NSString *const FRIEND_TABLE = @"t_friend";
static NSString *const BLACKLIST_TABLE = @"t_blacklist";

static int USER_TABLE_VERSION = 1;
static int GROUP_TABLE_VERSION = 1;
static int MY_GROUP_TABLE_VERSION = 1;
static int GROUP_MEMBER_TABLE_VERSION = 1;
static int FRIEND_TABLE_VERSION =1;
static int BLACKLIST_TABLE_VERSION = 1;

@implementation RCDDBManager

+ (BOOL)openDB:(NSString *)path {
    BOOL result = [RCDDBHelper openDB:path];
    if (result) {
        [self createTableIfNeed];
    }
    return result;
}

+ (void)closeDB {
    [RCDDBHelper closeDB];
}

+ (void)saveUsers:(NSArray<RCUserInfo *>*)userList {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"saveUsers, db is not open");
        return;
    }
    [RCDDBHelper executeTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *sql = @"REPLACE INTO t_user (user_id, name, portrait_uri) VALUES (?, ?, ?)";
        for (RCUserInfo *user in userList) {
            if (user.userId.length > 0) {
                NSString *name = user.name ?: @"";
                NSString *portrait = user.portraitUri ?: @"";
                NSArray *arr = @[user.userId, name, portrait];
                [db executeUpdate:sql withArgumentsInArray:arr];
            }
        }
    }];
}

+ (RCUserInfo *)getUser:(NSString *)userId {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getUser, db is not open");
        return nil;
    }
    if (userId.length == 0) {
        NSLog(@"getUser, userId length is zero");
        return nil;
    }
    __block RCUserInfo *userInfo = nil;
    NSString *sql = @"SELECT * FROM t_user WHERE user_id = ?";
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:@[userId]
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       if ([resultSet next]) {
                           userInfo = [self generateUserInfoFromFMResultSet:resultSet];
                       }
                   }];
    return userInfo;
}

+ (void)saveFriends:(NSArray<RCDFriendInfo *> *)friendList {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"saveFriends, db is not open");
        return;
    }
    [RCDDBHelper executeTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *userSql = @"REPLACE INTO t_user (user_id, name, portrait_uri) VALUES (?, ?, ?)";
        NSString *friendSql = @"REPLACE INTO t_friend (user_id, status, display_name, phone_number, update_dt) VALUES (?, ?, ?, ?, ?)";
        for (RCDFriendInfo *friend in friendList) {
            if (friend.userId.length > 0) {
                NSString *name = friend.name ?: @"";
                NSString *portrait = friend.portraitUri ?: @"";
                NSArray *userArr = @[friend.userId, name, portrait];
                [db executeUpdate:userSql withArgumentsInArray:userArr];
                
                NSString *displayName = friend.displayName ?: @"";
                NSString *phoneNumber = friend.phoneNumber ?: @"";
                NSArray *friendArr = @[friend.userId, @(friend.status), displayName, phoneNumber, @(friend.updateDt)];
                [db executeUpdate:friendSql withArgumentsInArray:friendArr];
            }
        }
    }];
}

+ (void)deleteFriends:(NSArray<NSString *> *)userIdList{
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"deleteFriends, db is not open");
        return;
    }
    [RCDDBHelper executeTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *friendSql = @"DELETE FROM t_friend WHERE user_id = ?";
        for (NSString *userId in userIdList) {
            if (userId.length > 0) {
                [db executeUpdate:friendSql withArgumentsInArray:@[userId]];
            }
        }
    }];
    
}

+ (RCDFriendInfo *)getFriend:(NSString *)userId {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getFriend, db is not open");
        return nil;
    }
    if (userId.length == 0) {
        NSLog(@"getFriend, userId length is zero");
        return nil;
    }
    __block RCDFriendInfo *friendInfo = nil;
    NSString *sql = @"SELECT u.user_id AS user_id, u.name AS name, u.portrait_uri AS portrait_uri, f.status AS status, f.display_name AS display_name, f.phone_number AS phone_number, f.update_dt AS update_dt FROM (t_friend AS f LEFT JOIN t_user AS u ON f.user_id = u.user_id) WHERE f.user_id = ?";
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:@[userId]
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       if ([resultSet next]) {
                           friendInfo = [self generateFriendInfoFromFMResultSet:resultSet];
                       }
                   }];
    return friendInfo;
}

+ (void)clearFriends {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"clearFriends, db is not open");
        return;
    }
    NSString *sql = @"DELETE FROM t_friend";
    [RCDDBHelper executeUpdate:sql withArgumentsInArray:nil];
}

+ (NSArray<RCDFriendInfo *> *)getAllFriends {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getAllFriends, db is not open");
        return nil;
    }
    __block NSMutableArray *friendList = [[NSMutableArray alloc] init];
    NSString *sql = @"SELECT u.user_id AS user_id, u.name AS name, u.portrait_uri AS portrait_uri, f.status AS status, f.display_name AS display_name, f.phone_number AS phone_number, f.update_dt AS update_dt FROM (t_friend AS f LEFT JOIN t_user AS u ON f.user_id = u.user_id) WHERE f.status = 20";
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:nil
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       while ([resultSet next]) {
                           RCDFriendInfo *userInfo = [self generateFriendInfoFromFMResultSet:resultSet];
                           [friendList addObject:userInfo];
                       }
                   }];
    return friendList;
}

+ (NSArray<RCDFriendInfo *> *)getAllFriendRequests {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getAllFriendRequests, db is not open");
        return nil;
    }
    __block NSMutableArray *friendList = [[NSMutableArray alloc] init];
    NSString *sql = @"SELECT u.user_id AS user_id, u.name AS name, u.portrait_uri AS portrait_uri, f.status AS status, f.display_name AS display_name, f.phone_number AS phone_number, f.update_dt AS update_dt FROM (t_friend AS f LEFT JOIN t_user AS u ON f.user_id = u.user_id) ORDER BY f.update_dt DESC";
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:nil
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       while ([resultSet next]) {
                           RCDFriendInfo *userInfo = [self generateFriendInfoFromFMResultSet:resultSet];
                           [friendList addObject:userInfo];
                       }
                   }];
    return friendList;
}

+ (void)addBlacklist:(NSArray<NSString *> *)userIdList {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"saveBlacklist, db is not open");
        return;
    }
    if (userIdList.count == 0) {
        NSLog(@"saveBlacklist, userIdList count is zero");
        return;
    }
    [RCDDBHelper executeTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSString *sql = @"REPLACE INTO t_blacklist (user_id) VALUES (?)";
        for (NSString *userId in userIdList) {
            if (userId.length > 0) {
                [db executeUpdate:sql withArgumentsInArray:@[userId]];
            }
        }
    }];
}

+ (NSArray<NSString *> *)getBlacklist {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getBlacklist, db is not open");
        return nil;
    }
    __block NSMutableArray *blacklistArray = [[NSMutableArray alloc] init];
    NSString *sql = @"SELECT * FROM t_blacklist";
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:nil
                   syncResult:^(FMResultSet *resultSet) {
                       while ([resultSet next]) {
                           NSString *userId = [resultSet stringForColumn:@"user_id"];
                           [blacklistArray addObject:userId];
                       }
                   }];
    return blacklistArray;
}

+ (void)removeBlacklist:(NSArray<NSString *> *)userIdList {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"clearBlacklist, db is not open");
        return;
    }
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM t_blacklist WHERE user_id IN ('%@')", [userIdList componentsJoinedByString:@"','"]];
    [RCDDBHelper executeUpdate:sql withArgumentsInArray:nil];
}

+ (void)clearBlacklist {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"clearBlacklist, db is not open");
        return;
    }
    NSString *sql = @"DELETE FROM t_blacklist";
    [RCDDBHelper executeUpdate:sql withArgumentsInArray:nil];
}

+ (void)saveGroups:(NSArray<RCDGroupInfo *> *)groupList {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"saveGroups, db is not open");
        return;
    }
    if (groupList.count == 0) {
        NSLog(@"saveGroups, userIdList count is zero");
        return;
    }
    NSString *sql = @"REPLACE INTO t_group (group_id, name, portrait_uri, member_count, max_count, introduce, creator_id, is_dismiss) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    [RCDDBHelper executeTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (RCDGroupInfo *groupInfo in groupList) {
            [db executeUpdate:sql withArgumentsInArray:@[groupInfo.groupId?:@"", groupInfo.groupName?:@"", groupInfo.portraitUri?:@"", @([groupInfo.number intValue]), @([groupInfo.maxNumber intValue]), groupInfo.introduce?:@"", groupInfo.creatorId?:@"", @(groupInfo.isDismiss)]];
        }
    }];
}

+ (RCDGroupInfo *)getGroup:(NSString *)groupId {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getGroup, db is not open");
        return nil;
    }
    if (groupId.length == 0) {
        NSLog(@"getGroup, groupId length is zero");
        return nil;
    }
    NSString *sql = @"SELECT * FROM t_group WHERE group_id = ?";
    __block RCDGroupInfo *group = nil;
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:@[groupId]
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       if ([resultSet next]) {
                           group = [self generateGroupInfoFromFMResultSet:resultSet];
                       }
                   }];
    return group;
}

+ (void)deleteGroup:(NSString *)groupId {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"deleteGroup, db is not open");
        return;
    }
    if (groupId.length == 0) {
        NSLog(@"deleteGroup, groupId length is zero");
        return;
    }
    NSString *sql = @"DELETE FROM t_group WHERE group_id = ?";
    [RCDDBHelper executeUpdate:sql
          withArgumentsInArray:@[groupId]];
}

+ (NSArray<RCDGroupInfo *>*)getAllGroupList{
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getAllGroupList, db is not open");
        return nil;
    }
    NSMutableArray *groups = [[NSMutableArray alloc] init];
    NSString *sql = @"SELECT * FROM t_group";
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:nil
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       while ([resultSet next]) {
                           RCDGroupInfo *group = [self generateGroupInfoFromFMResultSet:resultSet];
                           [groups addObject:group];
                       }
                   }];
    return groups;
}

+ (void)saveMyGroups:(NSArray<NSString *> *)groupIdList {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"saveMyGroups, db is not open");
        return;
    }
    NSString *sql = @"REPLACE INTO t_my_group (group_id) VALUES (?)";
    [RCDDBHelper executeTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (NSString *groupId in groupIdList) {
            if (groupId.length > 0) {
                [db executeUpdate:sql withArgumentsInArray:@[groupId]];
            }
        }
    }];
}

+ (NSArray<RCDGroupInfo *> *)getMyGroups {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getMyGroups, db is not open");
        return nil;
    }
    NSMutableArray *groups = [[NSMutableArray alloc] init];
    NSString *sql = @"SELECT g.* FROM (t_my_group AS m LEFT JOIN t_group AS g ON m.group_id = g.group_id)";
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:nil
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       while ([resultSet next]) {
                           RCDGroupInfo *group = [self generateGroupInfoFromFMResultSet:resultSet];
                           [groups addObject:group];
                       }
                   }];
    return groups;
}

+ (void)clearMyGroups {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"clearMyGroups, db is not open");
        return;
    }
    NSString *sql = @"DELETE FROM t_my_group";
    [RCDDBHelper executeUpdate:sql
          withArgumentsInArray:nil];
}

+ (void)saveGroupMembers:(NSArray<RCDGroupMember *> *)memberList inGroup:(NSString *)groupId{
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"saveGroupMembers, db is not open");
        return;
    }
    if (groupId.length == 0) {
        NSLog(@"saveGroupMembers, groupId length is zero");
        return;
    }
    [RCDDBManager saveUsers:memberList];
    NSString *sql = @"REPLACE INTO t_group_member (group_id, user_id, role, create_dt, update_dt) VALUES (?, ?, ?, ?, ?)";
    [RCDDBHelper executeTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (RCDGroupMember *member in memberList) {
            [db executeUpdate:sql withArgumentsInArray:@[groupId, member.userId, @(member.role), @(member.createDt),@(member.updateDt)]];
        }
    }];
}

+ (void)clearGroupMembers:(NSString *)groupId{
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"clearGroupMembers, db is not open");
        return;
    }
    if (groupId.length == 0) {
        NSLog(@"clearGroupMembers, groupId length is zero");
        return;
    }
    NSString *sql = @"DELETE FROM t_group_member WHERE group_id = ?";
    [RCDDBHelper executeUpdate:sql withArgumentsInArray:@[groupId]];
}

+ (NSArray<NSString *> *)getGroupMembers:(NSString *)groupId {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getGroupMembers, db is not open");
        return nil;
    }
    if (groupId.length == 0) {
        NSLog(@"getGroupMembers, groupId length is zero");
        return nil;
    }
    NSString *sql = @"SELECT * FROM t_group_member WHERE group_id = ? ORDER BY create_dt";
    NSMutableArray *members = [[NSMutableArray alloc] init];
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:@[groupId]
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       while ([resultSet next]) {
                           NSString *userId = [resultSet stringForColumn:@"user_id"];
                           [members addObject:userId];
                       }
                   }];
    return members;
}

+ (RCDGroupMember *)getGroupMember:(NSString *)userId inGroup:(NSString *)groupId{
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getGroupMember:inGroup: , db is not open");
        return nil;
    }
    if (groupId.length == 0 || userId.length == 0) {
        NSLog(@"getGroupMember:inGroup:, groupId or userId length is zero");
        return nil;
    }
    NSString *sql = @"SELECT gm.user_id, gm.group_id, gm.role, u.name, u.portrait_uri, gm.create_dt, gm.update_dt FROM t_group_member gm LEFT JOIN t_user u On gm.user_id = u.user_id WHERE gm.user_id = ? AND gm.group_id = ?";
    __block RCDGroupMember *member = [[RCDGroupMember alloc] init];
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:@[userId,groupId]
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       while ([resultSet next]) {
                           member.userId = [resultSet stringForColumn:@"user_id"];
                           member.name = [resultSet stringForColumn:@"name"];
                           member.portraitUri = [resultSet stringForColumn:@"portrait_uri"];
                           member.groupId = groupId;
                           member.role = [resultSet intForColumn:@"role"];
                       }
                   }];
    return member;
}

+ (NSArray<NSString *>*)getGroupManagers:(NSString *)groupId{
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getGroupManagers, db is not open");
        return nil;
    }
    if (groupId.length == 0) {
        NSLog(@"getGroupManagers, groupId length is zero");
        return nil;
    }
    NSString *sql = @"SELECT * FROM t_group_member WHERE group_id = ? AND role = ? ORDER BY create_dt";
    NSMutableArray *members = [[NSMutableArray alloc] init];
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:@[groupId,@(RCDGroupMemberRoleManager)]
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       while ([resultSet next]) {
                           NSString *userId = [resultSet stringForColumn:@"user_id"];
                           [members addObject:userId];
                       }
                   }];
    return members;
}

+ (NSString *)getGroupOwner:(NSString *)groupId{
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"getGroupOwner, db is not open");
        return nil;
    }
    if (groupId.length == 0) {
        NSLog(@"getGroupOwner, groupId length is zero");
        return nil;
    }
    NSString *sql = @"SELECT * FROM t_group_member WHERE group_id = ? AND role = ?";
    __block NSString *owner = [NSString string];
    [RCDDBHelper executeQuery:sql
         withArgumentsInArray:@[groupId,@(RCDGroupMemberRoleOwner)]
                   syncResult:^(FMResultSet * _Nonnull resultSet) {
                       while ([resultSet next]) {
                           owner = [resultSet stringForColumn:@"user_id"];
                       }
                   }];
    return owner;
}


+ (RCUserInfo *)generateUserInfoFromFMResultSet:(FMResultSet *)resultSet {
    RCUserInfo *userInfo = [[RCUserInfo alloc] init];
    userInfo.userId = [resultSet stringForColumn:@"user_id"];
    userInfo.name = [resultSet stringForColumn:@"name"];
    userInfo.portraitUri = [resultSet stringForColumn:@"portrait_uri"];
    return userInfo;
}

+ (RCDFriendInfo *)generateFriendInfoFromFMResultSet:(FMResultSet *)resultSet {
    RCDFriendInfo *friendInfo = [[RCDFriendInfo alloc] init];
    friendInfo.userId = [resultSet stringForColumn:@"user_id"];
    friendInfo.name = [resultSet stringForColumn:@"name"];
    friendInfo.portraitUri = [resultSet stringForColumn:@"portrait_uri"];
    friendInfo.status = [resultSet intForColumn:@"status"];
    friendInfo.displayName = [resultSet stringForColumn:@"display_name"];
    friendInfo.phoneNumber = [resultSet stringForColumn:@"phone_number"];
    friendInfo.updateDt = [resultSet longLongIntForColumn:@"update_dt"];
    return friendInfo;
}

+ (RCDGroupInfo *)generateGroupInfoFromFMResultSet:(FMResultSet *)resultSet {
    RCDGroupInfo *group = [[RCDGroupInfo alloc] init];
    group.groupId = [resultSet stringForColumn:@"group_id"];
    group.groupName = [resultSet stringForColumn:@"name"];
    group.portraitUri = [resultSet stringForColumn:@"portrait_uri"];
    group.number = [resultSet stringForColumn:@"member_count"];
    group.maxNumber = [resultSet stringForColumn:@"max_count"];
    group.introduce = [resultSet stringForColumn:@"introduce"];
    group.creatorId = [resultSet stringForColumn:@"creator_id"];
    group.isDismiss = [resultSet boolForColumn:@"is_dismiss"];
    return group;
}

+ (void)createTableIfNeed {
    if (![RCDDBHelper isDBOpened]) {
        NSLog(@"createTableIfNeed, db is not open");
        return;
    }
    [RCDDBHelper updateTable:USER_TABLE
                     version:USER_TABLE_VERSION
                 transaction:^BOOL(FMDatabase * _Nonnull db) {
                     NSString *sql = @"CREATE TABLE IF NOT EXISTS t_user ("
                     "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                     "user_id TEXT NOT NULL UNIQUE,"
                     "name TEXT,"
                     "portrait_uri TEXT"
                     ")";
                     BOOL result = [db executeUpdate:sql];
                     if (result) {
                         result = [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_user_id ON t_user(user_id)"];
                     }
                     return result;
                 }];
    
    [RCDDBHelper updateTable:FRIEND_TABLE
                     version:FRIEND_TABLE_VERSION
                 transaction:^BOOL(FMDatabase * _Nonnull db) {
                     NSString *sql = @"CREATE TABLE IF NOT EXISTS t_friend ("
                     "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                     "user_id TEXT NOT NULL UNIQUE,"
                     "status INTEGER,"
                     "display_name TEXT,"
                     "phone_number TEXT,"
                     "update_dt INTEGER"
                     ")";
                     BOOL result = [db executeUpdate:sql];
                     if (result) {
                         result = [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_friend_user_id ON t_friend(user_id) "];
                     }
                     return result;
                 }];
    
    [RCDDBHelper updateTable:GROUP_TABLE
                     version:GROUP_TABLE_VERSION
                 transaction:^BOOL(FMDatabase * _Nonnull db) {
                     NSString *sql = @"CREATE TABLE IF NOT EXISTS t_group ("
                     "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                     "group_id TEXT NOT NULL UNIQUE,"
                     "name TEXT,"
                     "portrait_uri TEXT,"
                     "member_count INTEGER,"
                     "max_count INTEGER,"
                     "introduce TEXT,"
                     "creator_id TEXT,"
                     "is_dismiss INTEGER"
                     ")";
                     BOOL result = [db executeUpdate:sql];
                     if (result) {
                         result = [db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_group_id ON t_group(group_id)"];
                     }
                     return result;
                 }];
    
    [RCDDBHelper updateTable:MY_GROUP_TABLE
                     version:MY_GROUP_TABLE_VERSION
                 transaction:^BOOL(FMDatabase * _Nonnull db) {
                     NSString *sql = @"CREATE TABLE IF NOT EXISTS t_my_group ("
                     "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                     "group_id TEXT NOT NULL UNIQUE"
                     ")";
                     return [db executeUpdate:sql];
                 }];
    
    [RCDDBHelper updateTable:BLACKLIST_TABLE
                     version:BLACKLIST_TABLE_VERSION
                 transaction:^BOOL(FMDatabase * _Nonnull db) {
                     NSString *sql = @"CREATE TABLE IF NOT EXISTS t_blacklist ("
                     "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                     "user_id TEXT NOT NULL UNIQUE"
                     ")";
                     return [db executeUpdate:sql];
                 }];
    
    [RCDDBHelper updateTable:GROUP_MEMBER_TABLE
                     version:GROUP_MEMBER_TABLE_VERSION
                 transaction:^BOOL(FMDatabase * _Nonnull db) {
                     NSString *sql = @"CREATE TABLE IF NOT EXISTS t_group_member ("
                     "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                     "group_id TEXT,"
                     "user_id TEXT,"
                     "role INTEGER,"
                     "create_dt INTEGER,"
                     "update_dt INTEGER"
                     ")";
                     BOOL result = [db executeUpdate:sql];
                     if (result) {
                         result = [db executeUpdate:@"CREATE UNIQUE INDEX IF NOT EXISTS idx_group_member ON t_group_member (group_id, user_id)"];
                     }
                     return result;
     }];
}
@end