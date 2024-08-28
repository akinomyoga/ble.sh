const fs = require("fs");

if (process.argv.length < 2) {
  console.error("usage: node color.sample.gogh.js <themes.json>");
  process.exit(2);
}
const input_filename = process.argv[2];

const json = JSON.parse(fs.readFileSync(input_filename, "utf8"));

console.log(`# ${json.length} themes are found in ${input_filename}.`);

var max_name_width = 0;
json.forEach(theme => {
  const name = theme.name.replace(/\s/g, "");
  const base16_colors = [
    theme.color_01,
    theme.color_02,
    theme.color_03,
    theme.color_04,
    theme.color_05,
    theme.color_06,
    theme.color_07,
    theme.color_08,
    theme.color_09,
    theme.color_10,
    theme.color_11,
    theme.color_12,
    theme.color_13,
    theme.color_14,
    theme.color_15,
    theme.color_16,
    theme.foreground,
    theme.background,
    theme.cursor,
  ];

  const buff = [];

  if (name.length > max_name_width)
    max_name_width = name.length;

  const rpad = 30 - name.length;
  buff.push(name);
  for (var i = 0; i < rpad; i++)
    buff.push(' ');
  base16_colors.forEach(c => buff.push(' ', c.replace(/^#/g, "0x")));

  console.log(buff.join(''));
});

console.log(`# max name width was ${max_name_width}`);
