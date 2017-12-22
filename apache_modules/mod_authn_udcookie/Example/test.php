<?PHP
//
// Simple page which tests the authn_udcookie module.  Sets a five-minute
// cookie according to the format expected by that module:
//
//    [user id]:[remote IP]:[expire time]:[random integer]:[cookie hash]
//
// The [expire time] is expected to be UTC time in a modified ISO 8601
// format:  YYYYmmddTHHMMSS.
//
// $Id: test.php 260 2009-11-10 17:38:33Z frey $
//

$cookieName = 'ud-nss-auth';
$cookieSecret = 'b8fe1a14004fde480179819713badeca';

$uid = 'frey';
$expire = gmstrftime('%Y%m%dT%H%M%S', time() + 300);
$rio = mt_rand();

$hash = md5(
          sprintf('%s %s %s %d %s %s',
              $uid,
              $_SERVER['REMOTE_ADDR'],
              $expire,
              $rio,
              $cookieName,
              $cookieSecret
            )
        );

$cookieValue = sprintf('%s,%s,%s,%d,%s',
                    $uid,
                    $_SERVER['REMOTE_ADDR'],
                    $expire,
                    $rio,
                    $hash
                  );

setcookie($cookieName, $cookieValue);

print_r($_SERVER);

?>
