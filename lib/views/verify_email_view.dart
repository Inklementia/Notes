import 'package:flutter/material.dart';
import 'package:notes/constants/routes.dart';
import 'package:notes/services/auth/auth_service.dart';

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({Key? key}) : super(key: key);

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Verify your email"),
        ),
        body: Column(
          children: [
            const Text(
                'We\'ve sent you an email verification. Please open it to verify your account.'),
            const Text(
                "If you haven't received a verification email yet, please press button below."),
            TextButton(
                onPressed: () async {
                  //final user = AuthService.firebase().currentUser;
                  await AuthService.firebase().sendEmailVerification();
                },
                child: const Text("Send email verification")),
            TextButton(
              onPressed: () async {
                AuthService.firebase().logOut();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  registerRoute,
                  (route) => false,
                );
              },
              child: const Text('Restart'),
            )
          ],
        ));
  }
}
