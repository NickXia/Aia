import navPolicyTest from './NavPolicy.test';
import urlUtilsTest from './UrlUtils.test';

export default function testsuite(): Array<string> {
  return [navPolicyTest, urlUtilsTest];
}
