const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

exports.generatePOIs = functions.https.onCall(async (data, context) => {
	const { location, tags } = data;
	const tagsString = tags.join(", ");
	const prompt = `Give me a list of tourist attractions in ${location} that include ${tagsString}.`;
	const apiKey = functions.config().openai.key;

	const response = await axios.post(
		"https://api.openai.com/v1/chat/completions",
		{
			model: "gpt-3.5-turbo",
			messages: [{ role: "system", content: prompt }],
			max_tokens: 150,
			temperature: 0.7,
		},
		{
			headers: {
				Authorization: `Bearer ${apiKey}`,
				"Content-Type": "application/json",
			},
		}
	);

	const data = response.data.choices[0].message.content;
	return data.split("\n").map((line) => {
		const parts = line.split(" - ");
		return {
			title: parts[0].trim(),
			description: parts[1] ? parts[1].trim() : "",
		};
	});
});
