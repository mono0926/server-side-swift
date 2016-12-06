
CREATE TABLE `users` (
	`id` VARCHAR(64) PRIMARY KEY NOT NULL,
	`password` VARCHAR(128),
	`salt` VARCHAR(512)
);

CREATE TABLE `posts` (
	`id` INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
	`user` VARCHAR(64) NOT NULL,
	`message` VARCHAR(140),
	`parent` INT,
	`date` DATETIME
);

CREATE TABLE `tokens` (
	`uuid` CHAR(36) PRIMARY KEY NOT NULL,
	`user` CHAR(64) NOT NULL,
	`expiry` DATETIME
);

INSERT INTO `users` VALUES ("twostraws", "a0e6ea6a2cedbc2de1e6a8b28d2db35643e00242f5d8167e978762f4e4f9742fb52f09e6e0a4111e93bc62b0981c4c6cee4bf60776beabc93773d583e80e35b9", "b5c7daa3207e85cdc06e32a91e7717f2426d55bc2a1d09b1bc8dc4fedba40dd543307e411fe3c8415341396fd230c7f9c99b52f7103d5a56d7b1bdf98f55f02e");
INSERT INTO `users` VALUES ("taylorswift13", "677e402fd07ec0ad5ed1045f23e6468a4e35993713cc994d451e2dadc61f40fedfff327190d90c0cf05b060365a734655aa05a70711561d3cf67db426ed76cc4", "76bdf75358b3b669099b6ef68507e312d9498801953645877db4a2014eb61c9bc4f8fce0f29b96156ef8bc6b07e873ca87777ec94964f5fdea48c64fc9d202ea");
INSERT INTO `users` VALUES ("adele", "6068e9623dcd6e80cf26bd27911db872dade357b6023159c05b2cbe81f32fb435c30811c354b7dd4d2c8b7a1752e1edcc4a669024ea311e43137b2960b60736e", "3798ee5a2f72fa396cfa947b5d9e9fe59db190c8d3352194243b13bc373552975f4e8d6670b7e3cb6650cfa2366eca2fd5267e3780390aca0131e68903e36ff4");

INSERT INTO `posts` (`user`, `message`, `date`) VALUES ("twostraws", "Just setting up my Barkr.", NOW());

INSERT INTO `posts` (`user`, `message`, `date`) VALUES ("twostraws", "At last my pet hamster has a voice in the world!", NOW());

INSERT INTO `posts` (`user`, `message`, `date`) VALUES ("taylorswift19", "This is just like Twitter, except I don't have eleventy billion followers.", NOW());