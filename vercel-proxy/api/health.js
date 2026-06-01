module.exports = (req, res) => {
  res.setHeader('access-control-allow-origin', '*');
  res.status(200).send('ok');
};
