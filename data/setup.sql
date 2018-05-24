-- Set up som stuff we need to test the script

-- A library that "on order" items can be connected to
INSERT IGNORE INTO branches SET branchcode = 'ONORDER', branchname = 'On order';
-- A library for electronic resources
INSERT IGNORE INTO branches SET branchcode = 'ELIB', branchname = 'E-library';

-- An itemtype for "on order" items
INSERT IGNORE INTO itemtypes SET itemtype = 'ONORDER', description = 'On order';
-- An itemtype for electronic resources
INSERT IGNORE INTO itemtypes SET itemtype = 'EBOOK', description = 'Ebook';

