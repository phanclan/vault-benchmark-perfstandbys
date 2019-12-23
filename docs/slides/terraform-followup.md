# Follow Up Email  

## **I. MATERIALS:**  

* **1)** Terraform Remote State (sharing information between projects/Workspaces):  
    * Docs: [<u>https://www.terraform.io/docs/providers/terraform/d/remote_state.html][1]</u>  

## **<u>II. RECAP:**</u>  

* **1) General Overview/Workflow:**  
    * With the additional collaboration and governance features available in Terraform Enterprise, you're able to create a centralized workflow for your deployments, giving you the ability to tie plans/applies to changes made within Version Control (more info [<u>here][2]</u>), or use the [<u>API][3]</u> to incorporate triggers within your CI/CD pipeline.  
    * Additionally, TFE can help you create more of a Producers/Consumers model by enabling your teams to create Modules and surface them to other teams for consumption within your own Private Module Registry (info [<u>here][4]</u>).  
    * For Security, you can take advantage of the granular [<u>RBAC][5]</u> controls available, [<u>Sensitive Credential][6]</u> management, State File management (encrypted, restricted, etc.), and Sentinel, our policy-as-code tool that enables you to set guardrails around your deployments.  
* **2) Feature Review**  
    * **_RBAC:_** Within Terraform Enterprise, you are able to assign users to different Teams, each of which can be given access to specific Workspaces, with appropriate levels of permission within them.  
    * **_STATE FILES:_** Within those Workspaces, State Files are managed for you, ensuring that they are non-corruptible and encrypted, to help protect the integrity of your deployments and provide an audit trail of changes made to your infrastructure over time.  
    * **_VARIABLES:_** Sensitive Variables, such as Cloud API Credentials, are likewise stored within Terraform Enterprise (encrypted at-rest, with write-only functionality), which allows you to avoid secret sprawl by removing the need to have such information living on Developers' machines or hard-coded elsewhere in your pipeline.  
    * **_SSO/SAML:_** You can connect Terraform Enterprise to your SSO or AD provider for added security so members of your organization can automatically get assigned to the correct teams in Terraform Enterprise (with appropriate levels of access and permission).  
    * **_AUDIT LOGGING:_** You're able to track not only the changes happening to your infrastructure, but also track activity within Terraform Enterprise itself (ex. which Users are accessing which Workspaces, Viewing/Modifying Variables, Triggering Plans/Applies, etc.).  
    * **_SENTINEL:_** Sentinel, our Policy-as-Code tool, allows you to apply additional guardrails around your deployments (ex. mandatory machine tagging, machine size limitations, security group enforcement, module version enforcement, etc.).  
* **3) Modules (Self-Service Infrastructure)**  
    * **_PRIVATE MODULE REGISTRY_**: As your adoption and usage of Terraform increases, we recommend decomposing any monolithic configurations into Modules which focus on smaller pieces of your deployments, as this enables you to easily reuse them in future projects.  To highlight this feature, we covered the Private Module Registry within TerraformEnterprise, as it allows your team to build Modules that are specific to your organization (and engender best practices for your deployments), and make those available to your team for consumption in a simple and easy to use manner.  
    * **_CONFIGURATION DESIGN TOOL_**:  
        * In order to reduce the barrier to adoption and enable all of your team members to start using Terraform in their projects, we covered the Configuration Design Tool that's available within Terraform Enterprise.  This tool gives your team the ability to select in a menu-style fashion which modules are needed for a given project and, after values are submitted for any optional or required inputs that are solicited, produces a preconfigured block of Terraform code that can be added to a repository.  As noted in the meeting, this tool helps your team adopt a more efficient (and secure) Producer-Consumer model so that all members can enjoy the benefits of using Terraform, regardless of his/her level of proficiency.  Further, all code generated through this tool will still go through the same centralized workflow for all deployments, guaranteeing consistency, visibility, and the same level of security (through TFE's Sensitive Variable management, Sentinel Policy enforcement, and RBAC system).  
* **4) Plans/Applies**  
    * There are a number of different methods available to interface with Terraform Enterprise to manage your plans/applies so you can use the tool within your desired workflow (ex. VCS vs CI/CD):  
        * - VCS/UI: [<u>https://www.terraform.io/docs/enterprise/run/ui.html][7]</u>  
        * - API: [<u>https://www.terraform.io/docs/enterprise/run/api.html][8]</u>  
        * - CLI: [<u>https://www.terraform.io/docs/enterprise/run/cli.html][9]</u>  
* Sample Terraform Enterprise Installation  
    * Source  
        * [github.com/hashicorp/private-terraform-enterprise/tree/automated-aws-pes-installation][10]  
* Sample Terraform Enterprise Automation Script  
    * Source  
        * [github.com/hashicorp/terraform-guides/tree/master/operations/automation-script][11]  

[1]: https://www.terraform.io/docs/providers/terraform/d/remote_state.html  
[2]: https://www.terraform.io/docs/enterprise/vcs/index.html  
[3]: https://www.terraform.io/docs/enterprise/api/index.html  
[4]: https://www.terraform.io/docs/enterprise/registry/index.html  
[5]: https://www.terraform.io/docs/enterprise/users-teams-organizations/index.html  
[6]: https://www.terraform.io/docs/enterprise/workspaces/variables.html  
[7]: https://www.terraform.io/docs/enterprise/run/ui.html  
[8]: https://www.terraform.io/docs/enterprise/run/api.html  
[9]: https://www.terraform.io/docs/enterprise/run/cli.html  
[10]: https://github.com/hashicorp/private-terraform-enterprise/tree/automated-aws-pes-installation  
[11]: https://github.com/hashicorp/terraform-guides/tree/master/operations/automation-script  
