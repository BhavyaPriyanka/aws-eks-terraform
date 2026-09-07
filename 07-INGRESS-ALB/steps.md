                         Internet
                            |
                            v
                    Route53 DNS
                            |
                            v
             localhelp-dev.localhelp.store
                            |
                            v
                    Public ALB
                    /          \
                  :80          :443
                   |             |
            Fixed Response   ACM Certificate
                                 |
                                 v
                         Host Header Rule
                                 |
                                 v
                     Frontend Target Group
                         IP : 8080
                                 |
                                 v
                          Frontend Pods