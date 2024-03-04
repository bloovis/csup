---
weight: 5
---

# Select Signature

```
A signature block (often abbreviated as signature, sig block, sig file,  
.sig, dot sig, siggy, or just sig) is a block of text automatically  
appended at the bottom of an e-mail message, Usenet article, or forum post. 
```
http://en.wikipedia.org/wiki/Signature_block

The default signature is specified on a per account base in sup's configuration.
The `:signature:` configuration option expects a path to a text file containing the signature.

The `edit_signature:` configuration option enables or disables manual editing of the signature while a message is composed.

A more flexible approach to generate signatures is the signature hook.
See the [signature hook]({{< relref "Hooks#signature" >}})
for more information.
