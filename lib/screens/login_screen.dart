import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String error = '';
  bool loading = false;
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Sign In to Spendly' : 'Register for Spendly'),
      ),
      body: Container(
        padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 50.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              SizedBox(height: 20.0),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: Validators.validateEmail,
                onChanged: (val) {
                  setState(() => email = val);
                },
              ),
              SizedBox(height: 20.0),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: Validators.validatePassword,
                obscureText: true,
                onChanged: (val) {
                  setState(() => password = val);
                },
              ),
              SizedBox(height: 20.0),
              ElevatedButton(
                child: Text(isLogin ? 'Sign In' : 'Register'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => loading = true);
                    dynamic result;
                    if (isLogin) {
                      result = await _auth.signInWithEmailAndPassword(
                        email,
                        password,
                      );
                    } else {
                      result = await _auth.registerWithEmailAndPassword(
                        email,
                        password,
                      );
                    }
                    if (result == null) {
                      setState(() {
                        error = 'Could not sign in with those credentials';
                        loading = false;
                      });
                    }
                  }
                },
              ),
              SizedBox(height: 10),
              OutlinedButton.icon(
                icon: Icon(
                  Icons.login,
                ), // You might want a Google logo asset here ideally
                label: Text('Sign in with Google'),
                onPressed: () async {
                  setState(() => loading = true);
                  final result = await _auth.signInWithGoogle();
                  if (result == null) {
                    setState(() {
                      error = 'Google Sign-In failed or cancelled';
                      loading = false;
                    });
                  }
                },
              ),
              SizedBox(height: 12.0),
              Text(error, style: TextStyle(color: Colors.red, fontSize: 14.0)),
              TextButton(
                child: Text(
                  isLogin
                      ? 'Need an account? Register'
                      : 'Have an account? Sign In',
                ),
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                    error = '';
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
