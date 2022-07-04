import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';

import 'HomePages.dart';
import 'SplashScreen.dart';

Future<Map> _calculateEncryptionValues(String pin) async {
  HashMap values = HashMap();

  // this should give us 256 bits? someone check my math
  final SecretKey randKey = SecretKey(
      List<int>.generate(32, (index) => Random.secure().nextInt(255)));
  final String randKeyStr = hex.encode(await randKey.extractBytes());
  values.putIfAbsent("randKey", () => randKeyStr);

  // utf8 or ascii here? I guess utf8 gives us a bigger PIN space?
  final SecretKey pinBytes = SecretKey(utf8.encode(pin));

  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha512(),
    iterations: 150000,
    bits: 256,
  );

  final SecretKey salt = SecretKey(
      List<int>.generate(16, (index) => Random.secure().nextInt(255)));
  final String saltStr = hex.encode(await salt.extractBytes());
  values.putIfAbsent("salt", () => saltStr);

  final userKey = await pbkdf2.deriveKey(
    secretKey: pinBytes,
    nonce: await salt.extractBytes(),
  );

  final sha512 = Sha512();
  final hashedUserKey = await sha512.hash(await userKey.extractBytes());
  final String hashedUserKeyStr = hex.encode(hashedUserKey.bytes);
  values.putIfAbsent("hashedUserKey", () => hashedUserKeyStr);

  final aes256 = AesGcm.with256bits();
  final aesNonce = aes256.newNonce();

  final encryptedRandKey = await aes256.encrypt(
    await randKey.extractBytes(),
    secretKey: userKey,
    nonce: aesNonce,
  );
  values.putIfAbsent(
      "randKeyCipherText", () => hex.encode(encryptedRandKey.cipherText));
  values.putIfAbsent("randKeyNonce", () => hex.encode(encryptedRandKey.nonce));
  values.putIfAbsent(
      "randKeyMAC", () => hex.encode(encryptedRandKey.mac.bytes));

  return values;
}

Future<bool> _registerPIN(String pin) async {
  final encryptionValues = await compute(_calculateEncryptionValues, pin);
  SharedPreferences prefs = await SharedPreferences.getInstance();

  final randKeyBytesStr = encryptionValues["randKey"];
  // TODO create sqflite_sqlcipher here with randKeyBytesStr

  prefs.setString("salt", encryptionValues["salt"]);
  prefs.setString("hashedUserKey", encryptionValues["hashedUserKey"]);

  prefs.setString("randKeyCipherText", encryptionValues["randKeyCipherText"]);
  prefs.setString("randKeyNonce", encryptionValues["randKeyNonce"]);
  prefs.setString("randKeyMAC", encryptionValues["randKeyMAC"]);

  prefs.setBool("onboarded", true);
  /* --------------------- */
  // this section is simulating a user login. TESTING ONLY! REMOVE LATER!
  /*String userEnteredPin = "test";

  final loginKeyGen = Pbkdf2(
    macAlgorithm: Hmac.sha512(),
    iterations: 200000,
    bits: 256,
  );

  final SecretKey loginPinBytes = SecretKey(utf8.encode(pin));

  final String loginSaltString = prefs.getString("salt").toString();
  final SecretKey loginSalt = SecretKey(hex.decode(loginSaltString));

  final loginUserKey = await loginKeyGen.deriveKey(
    secretKey: loginPinBytes,
    nonce: await loginSalt.extractBytes(),
  );

  final loginSha512 = Sha512();
  final loginHashedUserKey =
      await loginSha512.hash(await loginUserKey.extractBytes());
  final storedHashedUserKey = prefs.getString("hashedUserKey").toString();

  assert(hex.encode(loginHashedUserKey.bytes).hashCode ==
      storedHashedUserKey.hashCode);

  final storedRandKeyCipherText =
      hex.decode(prefs.getString("randKeyCipherText").toString());
  final storedRandKeyNonce =
      hex.decode(prefs.getString("randKeyNonce").toString());
  final storedRandKeyMAC = hex.decode(prefs.getString("randKeyMAC").toString());

  final storedBox = SecretBox(
    storedRandKeyCipherText,
    nonce: storedRandKeyNonce,
    mac: Mac(storedRandKeyMAC),
  );

  final loginAES = AesGcm.with256bits();

  final clearText = await loginAES.decrypt(storedBox, secretKey: loginUserKey);
  final clearTextStr = hex.encode(clearText);
  assert(clearTextStr.hashCode == randKeyBytesHexStr.hashCode);*/
  /* --------------------- */

  //await Future.delayed(const Duration(seconds: 5));

  return true;
}

class RegistrationLoadingPage extends StatefulWidget {
  final String pin;

  const RegistrationLoadingPage({Key? key, required this.pin})
      : super(key: key);

  @override
  State<RegistrationLoadingPage> createState() =>
      _RegistrationLoadingPageState();
}

class _RegistrationLoadingPageState extends State<RegistrationLoadingPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _registerPIN(widget.pin),
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return const SplashScreen();
        } else {
          return const HomePages();
        }
      },
    );
  }
}

void _submitRegistrationForm(
    GlobalKey<FormState> key, BuildContext context, String pin) {
  if (key.currentState!.validate()) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => RegistrationLoadingPage(pin: pin)),
      (route) => false,
    );
  }
}

class RegistrationForm extends StatefulWidget {
  const RegistrationForm({Key? key}) : super(key: key);

  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstPIN = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              "Enter a PIN:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextFormField(
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              // enableInteractiveSelection: true, // should be true if obscureText = true
              // maxLines: 1, // defaults to 1
              obscureText:
                  true, // also disables stupid shit like gif and emoji keyboard
              controller: _firstPIN,
              autofocus: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a PIN';
                }
                return null;
              },
              textInputAction: TextInputAction.next,

              //keeping the input format stuff out for now; trusting people to not be dumbasses
              /*inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              ],*/
            ),
            const Text("Confirm your PIN:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              obscureText: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              textInputAction: TextInputAction.go,
              validator: (value) {
                if (value != _firstPIN.text) {
                  return "PINs do not match!";
                }
                return null;
              },
              onFieldSubmitted: (value) {
                _submitRegistrationForm(_formKey, context, _firstPIN.text);
              },
            ),
            ElevatedButton(
              onPressed: () {
                _submitRegistrationForm(_formKey, context, _firstPIN.text);
                /*if(_formKey.currentState!.validate()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Processing data')),
                  );
                }*/
              },
              child: const Text('Submit'),
            )
          ],
        ),
      ),
    );
  }
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({Key? key}) : super(key: key);

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: RegistrationForm(),
    );
  }
}