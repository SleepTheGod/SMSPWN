# Warning
Activities such as mass automated calling/SMS without explicit opt-in consent almost always violate
U.S. federal law (Telephone Consumer Protection Act 47 U.S.C. § 227, CAN-SPAM Act)
Most countries' anti-spam / anti-harassment legislation
Every major carrier's acceptable-use policy
Cloud/hosting provider terms of service
In many cases, computer-fraud and wire-fraud statutes when done at scale with intent to disrupt

**LEGAL DISCLAIMER**

**Copyright © 2025 Taylor Christian Newsome. All rights reserved.**

**1. EDUCATIONAL PURPOSE ONLY**
This code, software, and associated files ("the Material") is published by Taylor Christian Newsome ("I", "me", or "my") **solely for educational and laboratory research purposes**. The Material is intended to be used exclusively in controlled, private lab environments for academic study and security research.

**2. NO LIABILITY**
I, Taylor Christian Newsome, am **NOT RESPONSIBLE** and **DISCLAIM ALL LIABILITY** for any use or misuse of this Material. I expressly assume no liability for:

- Violations of the Telephone Consumer Protection Act (TCPA), 47 U.S.C. § 227
- Violations of the CAN-SPAM Act
- Violations of any federal or state anti-spam, anti-harassment, or consumer protection laws
- Violations of any international anti-spam legislation (including CASL, GDPR, etc.)
- Breaches of carrier, provider, or platform Acceptable Use Policies
- Violations of the Computer Fraud and Abuse Act (CFAA)
- Any wire fraud, computer fraud, or criminal statutes
- Any fines, penalties, or legal actions brought by the FCC, FTC, or any governmental authority

**3. LAB USE ONLY DESIGNATION**
This Material is designated **"LAB USE ONLY"** and is strictly prohibited from being used:

- In any production environment
- Against live telecommunications networks, cellular networks, or SMS gateways
- To contact any person without their explicit, verifiable, prior written consent
- For any commercial purpose
- For any unlawful purpose

**4. NO CONTROL OVER USE**
I have no control over who downloads, modifies, or uses this Material. I do not endorse, support, or encourage any unlawful use. Any use of this Material for automated calling, mass messaging, or unsolicited communications is done **entirely at the user's own risk** and is a violation of these terms.

**5. INDEMNIFICATION**
By accessing, downloading, or using this Material, you agree to indemnify, defend, and hold harmless Taylor Christian Newsome from any and all claims, liabilities, damages, losses, or expenses arising from your use of this Material.

**6. GOVERNING LAW**
This disclaimer shall be governed by the laws of the United States.

**BY DOWNLOADING, VIEWING, OR USING THIS MATERIAL, YOU ACKNOWLEDGE THAT YOU HAVE READ THIS DISCLAIMER AND AGREE THAT TAYLOR CHRISTIAN NEWSOME BEARS NO RESPONSIBILITY FOR YOUR ACTIONS.**

```
███████╗███╗   ███╗███████╗    ██████╗ ██████╗ ██╗██╗   ██╗███████╗    ██████╗ ██╗   ██╗                
██╔════╝████╗ ████║██╔════╝    ██╔══██╗██╔══██╗██║██║   ██║██╔════╝    ██╔══██╗╚██╗ ██╔╝                
███████╗██╔████╔██║███████╗    ██║  ██║██████╔╝██║██║   ██║█████╗      ██████╔╝ ╚████╔╝                 
╚════██║██║╚██╔╝██║╚════██║    ██║  ██║██╔══██╗██║╚██╗ ██╔╝██╔══╝      ██╔══██╗  ╚██╔╝                  
███████║██║ ╚═╝ ██║███████║    ██████╔╝██║  ██║██║ ╚████╔╝ ███████╗    ██████╔╝   ██║                   
╚══════╝╚═╝     ╚═╝╚══════╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝    ╚═════╝    ╚═╝                   
                                                                                                        
███████╗██╗ ██████╗ ██╗   ██╗██████╗ ███████╗    ██╗████████╗     ██████╗ ██╗   ██╗████████╗            
██╔════╝██║██╔════╝ ██║   ██║██╔══██╗██╔════╝    ██║╚══██╔══╝    ██╔═══██╗██║   ██║╚══██╔══╝            
█████╗  ██║██║  ███╗██║   ██║██████╔╝█████╗      ██║   ██║       ██║   ██║██║   ██║   ██║               
██╔══╝  ██║██║   ██║██║   ██║██╔══██╗██╔══╝      ██║   ██║       ██║   ██║██║   ██║   ██║               
██║     ██║╚██████╔╝╚██████╔╝██║  ██║███████╗    ██║   ██║       ╚██████╔╝╚██████╔╝   ██║               
╚═╝     ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚═╝   ╚═╝        ╚═════╝  ╚═════╝    ╚═╝               
                                                                                                        
██████╗ ███████╗ █████╗ ██████╗     ████████╗██╗  ██╗███████╗     ██████╗ ██████╗ ██████╗ ███████╗      
██╔══██╗██╔════╝██╔══██╗██╔══██╗    ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝      
██████╔╝█████╗  ███████║██║  ██║       ██║   ███████║█████╗      ██║     ██║   ██║██║  ██║█████╗        
██╔══██╗██╔══╝  ██╔══██║██║  ██║       ██║   ██╔══██║██╔══╝      ██║     ██║   ██║██║  ██║██╔══╝        
██║  ██║███████╗██║  ██║██████╔╝       ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██████╔╝███████╗      
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝        ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝      
                                                                                                        
███████╗██╗███╗   ██╗ ██████╗███████╗    ██╗   ██╗ ██████╗ ██╗   ██╗    ██╗  ██╗ █████╗  ██████╗██╗  ██╗
██╔════╝██║████╗  ██║██╔════╝██╔════╝    ╚██╗ ██╔╝██╔═══██╗██║   ██║    ██║  ██║██╔══██╗██╔════╝██║ ██╔╝
███████╗██║██╔██╗ ██║██║     █████╗       ╚████╔╝ ██║   ██║██║   ██║    ███████║███████║██║     █████╔╝ 
╚════██║██║██║╚██╗██║██║     ██╔══╝        ╚██╔╝  ██║   ██║██║   ██║    ██╔══██║██╔══██║██║     ██╔═██╗ 
███████║██║██║ ╚████║╚██████╗███████╗       ██║   ╚██████╔╝╚██████╔╝    ██║  ██║██║  ██║╚██████╗██║  ██╗
╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝       ╚═╝    ╚═════╝  ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
```
If you don't understand the code then you don't know what you are doing and don't need to be here.
