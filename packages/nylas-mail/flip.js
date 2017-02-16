let i = 0;
let cur = "";
let last = "";
let HH = 0;
let HT = 0;
while (i < 1000000) {
  cur = Math.round(Math.random()) ? "H" : "T"

  if (last + cur === "HH") {
    // cur = "";
    // last = "";
    HH++;
  }
  last = cur;
  i++;
}
i = 0;
while (i < 1000000) {
  cur = Math.round(Math.random()) ? "H" : "T"
  if (last + cur == "HT") {
    // cur = "";
    // last = "";
    HT++;
  }
  last = cur;
  i++;
}
console.log("HH", HH, HH / (HH + HT))
console.log("HT", HT, HT / (HH + HT))
