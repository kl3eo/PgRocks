----------------------------------------------------------------------------------------------------------------------------------------------------
-- destroys all RocksDB stores marked in the table's v3_dna and then erases its v3_dna
-- table_name$1
----------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _d_rocksdb3(text)
RETURNS integer AS $$
DECLARE 

r int;
BEGIN

FOR r IN
EXECUTE format('SELECT distinct mark from %s_v3_dna order by mark',$1)
    LOOP
EXECUTE format('select rocks_destroy(%s)',  r);
    END LOOP;
EXECUTE format('select _i_v3_dna(''%s'', 0)',  $1);

RETURN 0;

END;$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------------------------------------
-- initialize/destroy v3_dna for table_name$1, flag$2
-- table_name$1, flag$2
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _i_v3_dna(text, int)
RETURNS integer AS $$
DECLARE 

resultCount integer := 0;

BEGIN


EXECUTE format('drop table if exists %s_v3_dna', $1);

if $2 = 1 then 
EXECUTE format('create table %s_v3_dna (mark int, rev int, key bigint, ancestor bigint)', $1);
end if;
  
RETURN resultCount;

END;$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------------------------------------
-- this function should ONLY be used from a script making sure the marks should not intersect
-- table_name$1, mark$2, limit$3, offset$4, order$5
-----------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _e_v3_dna(text, int, int, int, text)
RETURNS integer AS $$
DECLARE 
resultCount integer := 0;
table_exists bool;

BEGIN

-- EXECUTE format('SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = ''public'' AND table_name = ''%s_new'')',$1) into table_exists;

-- if table_exists is false then
-- EXECUTE format('create unlogged table %s_new as select * from %s limit 0',$1,$1);
-- EXECUTE format('alter table %s_new add column my_%s_new_id bigserial',$1,$1);
-- EXECUTE format('insert into %s_new select * from %s',$1,$1);
-- EXECUTE format('alter table %s_new add primary key (my_%s_new_id)',$1,$1);
-- end if;

EXECUTE format('CREATE TEMP TABLE tmp on commit drop as select * from %s_new limit 0',$1);
EXECUTE format('CREATE TEMP TABLE v3_dna_tmp (mark int, rev int, key bigint, ancestor bigint) on commit drop');

-- EXECUTE format('insert into tmp select * from %s limit %s offset %s',$1,$3,$4);
-- or even
-- EXECUTE format('WITH moved_rows AS ( SELECT * FROM %s_new WHERE my_%s_new_id  = ANY(ARRAY(SELECT my_%s_new_id FROM %s_new order by my_%s_new_id %s LIMIT %s offset %s)) ) insert into tmp select * from moved_rows',$1,$1,$1,$1,$1,$5,$3,$4);
-- faster?

EXECUTE format('insert into tmp SELECT * FROM %s_new order by my_%s_new_id %s LIMIT %s offset %s',$1,$1,$5,$3,$4);
EXECUTE format('alter table tmp drop column my_%s_new_id',$1);
EXECUTE format('insert into v3_dna_tmp (mark, rev, key) select %s,1,row_to_csv_rocks(%s,tmp) from tmp',$2,$2);
EXECUTE format('update v3_dna_tmp set ancestor=key');
EXECUTE format('insert into %s_v3_dna select * from v3_dna_tmp',$1);
EXECUTE format('select rocks_close()');

RETURN resultCount;

END;$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------------------------------------
-- workhorse of _e_c0 in sequential mode; runs in parallel when started from script
-- table_name$1, mark$2
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _e_checkout_c0(text,int)
RETURNS integer AS $$

DECLARE
table_exists bool;

BEGIN

EXECUTE format('SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = ''public'' AND table_name = ''%s_c0'')',$1) into table_exists;
   
if ($1 = 'players' or $1 = 'p') then

else 
RETURN -1;
end if;

if table_exists is false then

if $1 = 'players' then

-- EXECUTE format('create unlogged table %s_c0 with oids as select key, d.*  
-- from %s_v3_dna, rocks_csv_to_record(%s,%s_v3_dna.key) 
-- d(name text, aka text, dob date, weight float, height int, last_seen timestamp
-- ) where %s_v3_dna.rev  > 0 and %s_v3_dna.mark = %s',$1,$1,$2,$1,$1,$1,$2);

EXECUTE format('create table %s_c0 (key bigint, name text, aka text, dob date, weight float, height int, last_seen timestamp) with oids',$1);

elsif $1 = 'p' then

-- EXECUTE format('create unlogged table %s_c0 with oids as select key, d.*  
-- from %s_v3_dna, rocks_csv_to_record(%s,%s_v3_dna.key) 
-- d(occ bigint, goc bigint, kbd smallint, otc text, kba smallint, otv text, 
-- oav oid, kia int, kib int, kbb smallint, odb date, 
-- obb bool, obc bool, ona int, kic int, obd bool, odc timestamp, otn text,
-- obf bool, obg bool, kbc smallint, obh bool, k2c smallint, odd timestamp, k2b smallint,
-- oda timestamp, k2d smallint, ode timestamp, k2a smallint
-- ) where %s_v3_dna.rev  > 0 and %s_v3_dna.mark = %s',$1,$1,$2,$1,$1,$1,$2);

EXECUTE format('create table %s_c0 (key bigint, occ bigint, goc bigint, kbd smallint, otc text, kba smallint, otv text, 
oav oid, kia int, kib int, kbb smallint, odb date, 
obb bool, obc bool, ona int, kic int, obd bool, odc timestamp, otn text,
obf bool, obg bool, kbc smallint, obh bool, k2c smallint, odd timestamp, k2b smallint,
oda timestamp, k2d smallint, ode timestamp, k2a smallint) with oids',$1);

end if;

elsif table_exists is true then

if $1 = 'players' then

EXECUTE format('insert into %s_c0 select key, d.*  
from %s_v3_dna, rocks_csv_to_record(%s,%s_v3_dna.key) 
d(name text, aka text, dob date, weight float, height int, last_seen timestamp
) where %s_v3_dna.rev  > 0 and %s_v3_dna.mark = %s',$1,$1,$2,$1,$1,$1,$2);

elsif $1 = 'p' then

EXECUTE format('insert into %s_c0 select key, d.*  
from %s_v3_dna, rocks_csv_to_record(%s,%s_v3_dna.key) 
d(occ bigint, goc bigint, kbd smallint, otc text, kba smallint, otv text, 
oav oid, kia int, kib int, kbb smallint, odb date, 
obb bool, obc bool, ona int, kic int, obd bool, odc timestamp, otn text,
obf bool, obg bool, kbc smallint, obh bool, k2c smallint, odd timestamp, k2b smallint,
oda timestamp, k2d smallint, ode timestamp, k2a smallint
) where %s_v3_dna.rev  > 0 and %s_v3_dna.mark = %s',$1,$1,$2,$1,$1,$1,$2);

end if;

end if;

EXECUTE format('select rocks_close()');


RETURN 0;

END;$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------------------------------------
-- trigger function used in checkout and rewind
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _ew_new_row()
returns trigger AS $_ew_new_row$

DECLARE
v bigint := 0;
rev_old int := 1;
mark_old int := 0;
payload text;
vc text;
ancs text;

BEGIN

IF (TG_OP = 'INSERT') THEN


EXECUTE 'select rocks_get_node_number()' into v;

-- here we strongly depend on that key of the insert has been already formed correctly somewhere as:
-- select cast( rocks_get_node_number()*10000000000000000+ EXTRACT(EPOCH FROM current_timestamp)*1000000 as bigint);
-- otherwise catch all sorts of error

IF (floor(NEW.key/10000000000000000) = 0 or NEW.key IS NULL) THEN
RAISE NOTICE 'BAD KEY(''%''): exiting',NEW.key;
RETURN NULL;
END IF;
RAISE NOTICE 'new key(''%''):',NEW.key;

IF (v = floor(NEW.key/10000000000000000)) THEN

drop table if exists tmp;
CREATE TEMP TABLE tmp on commit drop as select NEW.*;
ALTER TABLE tmp drop column key;
-- we're ad hoc putting new rec into store=TG_ARGV[1]; we're free to chose one
EXECUTE format('select row_to_csv_rocks(%s,tmp) from tmp',TG_ARGV[1]) into v;
EXECUTE format('select rocks_close()');

EXECUTE format('select cast(%s as text)',v) into vc;
payload := (SELECT TG_ARGV[1] || ',' || json_build_object('tab',TG_ARGV[0],'rev',1,'key',vc, 'ancestor',vc) );
  perform pg_notify('v3_dna_insert', payload); 

EXECUTE format('insert into %s_v3_dna (mark, rev, key, ancestor) values(%s,1,%s,%s)',TG_ARGV[0],TG_ARGV[1],v,v);
NEW.key = v;

END IF;
RETURN NEW;

ELSIF (TG_OP = 'UPDATE') THEN
drop table if exists tmp;
CREATE TEMP TABLE tmp on commit drop as select NEW.*;
ALTER TABLE tmp drop column key;

EXECUTE format('select mark, rev, ancestor::text from %s_v3_dna where key = %s',TG_ARGV[0],NEW.key) into mark_old, rev_old, ancs ;

EXECUTE format('select row_to_csv_rocks(%s,tmp) from tmp', mark_old) into v;
EXECUTE format('select rocks_close()');

EXECUTE format('select cast(%s as text)',v) into vc;
payload := (SELECT mark_old || ',' || json_build_object('tab',TG_ARGV[0],'rev',rev_old+1,'key',vc, 'ancestor', ancs) );
  perform pg_notify('v3_dna_insert', payload);

EXECUTE format('insert into %s_v3_dna (mark, rev, key, ancestor) values (%s,%s,%s,%s)',TG_ARGV[0],mark_old,rev_old+1,v,ancs);

EXECUTE format('select cast(%s as text)',NEW.key) into vc;
payload := (SELECT TG_ARGV[0] || ',' || json_build_object('rev',rev_old*(-1),'key',vc,'ancestor', ancs) );
perform pg_notify('v3_dna_update', payload); 

EXECUTE format('update %s_v3_dna set rev = %s where key = %s',TG_ARGV[0],rev_old*(-1),NEW.key);

NEW.key = v;
RETURN NEW;

ELSIF (TG_OP = 'DELETE') THEN

EXECUTE format('select mark, rev, ancestor::text from %s_v3_dna where key = %s',TG_ARGV[0],OLD.key) into mark_old, rev_old, ancs;

IF (rev_old > 0) THEN
EXECUTE 'select cast( rocks_get_node_number()*10000000000000000+ EXTRACT(EPOCH FROM current_timestamp)*1000000 as bigint)' into v;
EXECUTE format('select cast( %s as text)',v) into vc;

payload := (SELECT mark_old || ',' || json_build_object('tab',TG_ARGV[0],'rev',0,'key',vc,'ancestor', ancs) );
perform pg_notify('v3_dna_insert', payload); 

EXECUTE format('insert into %s_v3_dna (mark, rev, key, ancestor) values(%s,0,%s,%s)',TG_ARGV[0],mark_old,vc,ancs);

EXECUTE format('select cast(%s as text)',OLD.key) into vc;

payload := (SELECT TG_ARGV[0] || ',' || json_build_object('rev',rev_old*(-1),'key',vc,'ancestor', ancs) );
perform pg_notify('v3_dna_update', payload); 

EXECUTE format('update %s_v3_dna set rev = %s where key = %s',TG_ARGV[0],rev_old*(-1),OLD.key);

END IF;

RETURN OLD;

END IF;

END;$_ew_new_row$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------------------------------------
-- used to insert external data to local cache
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _e_atomic_c0(text,int,bigint)

RETURNS integer AS $$

BEGIN

if ($1 = 'players' or $1 = 'p') then

else 
	RETURN -1;
end if;

drop table if exists tmp;

if $1 = 'players' then

EXECUTE format('create temp table tmp on commit drop as select %s, d.*  
from %s_sv3_dna, rocks_csv_to_record(%s,%s)
d(name text, aka text, dob date, weight float, height int, last_seen timestamp
) where %s_v3_dna.key = %s',$3,$1,$2,$3,$1,$3);
EXECUTE format('insert into %s_c0 select * from tmp',$1);

elsif $1 = 'p' then

EXECUTE format('create temp table tmp on commit drop as select %s, d.*  
from %s_v3_dna, rocks_csv_to_record(%s,%s)
d(occ bigint, goc bigint, kbd smallint, otc text, kba smallint, otv text, 
oav oid, kia int, kib int, kbb smallint, odb date, 
obb bool, obc bool, ona int, kic int, obd bool, odc timestamp, otn text,
obf bool, obg bool, kbc smallint, obh bool, k2c smallint, odd timestamp, k2b smallint,
oda timestamp, k2d smallint, ode timestamp, k2a smallint
) where %s_v3_dna.key = %s',$3,$1,$2,$3,$1,$3);
EXECUTE format('insert into %s_c0 select * from tmp',$1);

end if;

EXECUTE format('select rocks_close()');

RETURN 0;

END;$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------------------------------------------
-- wrapper for _e_checkout_c0; scans the v3_dna and checks out from the RocksDB stores related by 'mark' field
-- table_name$1, num_stores$2
--------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _e_c0(text, int)
returns integer AS $$

DECLARE 
r int;
resultCount integer := 0;
chosen_mark int := 0;

BEGIN

EXECUTE format('drop table if exists %s_c0',$1); 

--- instead of this loop, start perl script from shell and do _e_checkout_c0 in parallel
FOR r IN EXECUTE format('SELECT distinct mark from %s_v3_dna order by mark', $1)
    LOOP
	RAISE NOTICE 'Executing _e_checkout_c0(''%'',%):',$1,r;
	EXECUTE format('select _e_checkout_c0(''%s'',%s)',$1,r) into r;
	resultCount = resultCount + 1;
    END LOOP;
-- end perl loop

EXECUTE format('SELECT floor(random()*%s + 1)::int', $2) into chosen_mark;

EXECUTE format('DROP TRIGGER IF EXISTS %s_c0_biud_v3 ON %s_c0',$1,$1);

EXECUTE format('CREATE TRIGGER %s_c0_biud_v3
BEFORE INSERT OR UPDATE OR DELETE 
ON %s_c0
FOR EACH ROW
EXECUTE PROCEDURE _ew_new_row(''%s'',%s);',$1,$1,$1,chosen_mark);

RETURN resultCount;

END;$$ LANGUAGE plpgsql;
-----------------------------------------------------------------------------------------------------------------
-- end lib
-----------------------------------------------------------------------------------------------------------------
