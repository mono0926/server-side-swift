DROP TABLE IF EXISTS `categories`;
DROP TABLE IF EXISTS `posts`;

CREATE TABLE `categories` (
	`id` INT AUTO_INCREMENT PRIMARY KEY,
	`name` VARCHAR(64)
);

INSERT INTO `categories` (`id`, `name`) VALUES (1, 'Features');
INSERT INTO `categories` (`id`, `name`) VALUES (2, 'News');
INSERT INTO `categories` (`id`, `name`) VALUES (3, 'Reviews');
INSERT INTO `categories` (`id`, `name`) VALUES (4, 'Tutorials');

CREATE TABLE `posts` (
	`id` INT AUTO_INCREMENT PRIMARY KEY,
	`title` VARCHAR(255) NOT NULL,
	`strap` VARCHAR(255) NOT NULL,
	`content` TEXT NOT NULL,
	`category` INT NOT NULL,
	`slug` VARCHAR(255) NOT NULL,
	`date` DATETIME NOT NULL
);

INSERT INTO `posts` (`title`, `strap`, `content`, `category`, `slug`, `date`) VALUES ("iPhone 7 review", "Don't miss our exclusive hands-on", "**The iPhone 7 promises to be the best ever, but does it live up to that claim?**\n\nYes. The End.", 3, "iphone-7-review", NOW());
INSERT INTO `posts` (`title`, `strap`, `content`, `category`, `slug`, `date`) VALUES ("How to write macOS apps", "It's easier thank you think!", "You should buy [Hacking with macOS](https://www.hackingwithswift.com/store/hacking-with-macos).", 4, "how-to-write-macos-apps", NOW());

