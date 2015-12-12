
export const wait = (ms)=> {
  return new Promise((resolve)=> {
    setTimeout(()=> resolve(), ms);
  });
};

export const clickRepeat = (client, selector, {times = 1, interval = 0} = {})=> {
  if (times === 1) return client.click(selector);
  const fn = (remaining)=> {
    if (remaining > 0) {
      return (
        client.click(selector)
        .then(()=> wait(interval))
        .then(()=> fn(remaining - 1))
      );
    }
  };
  return fn(times);
};
