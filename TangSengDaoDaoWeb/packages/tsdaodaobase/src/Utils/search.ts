

export function getQueryParam(key: string) {
  const params = new URLSearchParams(window.location.search);
  return params.get(key); // 不存在返回 null
}

export function getSid() {
  let sid = getQueryParam("sid");
  if (!sid || sid === "") {
   // 如果为空 则随机生成一个6位数的字符串
   sid = Math.random().toString(36).slice(-6);
  }
  return sid;
}
