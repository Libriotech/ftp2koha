-- Run this to remove the data added by testing

DELETE FROM biblio WHERE biblionumber IN ( SELECT biblionumber FROM biblio_metadata WHERE ExtractValue( metadata, '//controlfield[@tag="001"]' ) = 'MySpecial001' );
