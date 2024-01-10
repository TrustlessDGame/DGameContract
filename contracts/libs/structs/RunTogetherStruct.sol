// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library RunTogetherObjectStruct {
    struct RunTogetherEvent {
        string _creator;
        address _creatorAddr;
        string _name;
        string _image;
        string _desc;
    }

    struct RunTogetherParticipant {
        string _groupId;
        string _twitterId;
        string _stravaId;
        string _data;
    }
}
