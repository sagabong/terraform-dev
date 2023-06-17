# Variables
resource "aws_imagebuilder_component" "snow_int_ec2_build" {
  name        = "snow_int_ec2_build"
  description = "Install ServiceNow with dependencies"
  platform    = "Linux"
  version     = "1.0.0"
  data = yamlencode({
    phases = [{
      name = "build"
      steps = [
        {
          name   = "Set_TimeZone_Create_User_Accounts_Install_Packages_Kernel_Parameters_and_ULimits_autoStartService"
          action = "ExecuteBash"
          inputs = {
            commands = [
              "sudo aws s3 cp s3://terraform-snow/glide-utah-12-21-2022__patch3-04-20-2023_05-04-2023_2316.zip /tmp/",
              "sudo aws s3 cp s3://terraform-snow/snc_dev.service /tmp/",
              "sudo timedatectl set-timezone UTC",
              "sudo useradd servicenow",
              "sudo yum install -y java-11-openjdk-devel",
              "sudo yum install -y glibc.i686 glibc.x86_64",
              "sudo yum install -y libgcc.i686 libgcc.x86_64",
              "sudo yum install -y rng-tools.i686 rng-tools.x86_64",
              "sudo yum install -y mariadb",
              "echo 'vm.swappiness=1' | sudo tee -a /etc/sysctl.conf",
              "sudo sysctl -p",
              "echo '* soft nproc 10240' | sudo tee /etc/security/limits.d/90-nproc.conf",
              "echo '* soft nofile 16000' | sudo tee /etc/security/limits.d/amb-sockets.conf",
              "echo '* hard nofile 16000' | sudo tee -a /etc/security/limits.d/amb-sockets.conf",
              "export J_HOME=/usr/lib/jvm/$(ls /usr/lib/jvm | grep java-11-openjdk-11)",
              "echo 'JAVA_HOME=$J_HOME' | sudo tee -a /etc/environment"
            ]
          }
        },
        {
          name   = "verifyPackages"
          action = "ExecuteBash"
          inputs = {
            commands = [
              "echo TESTING...",
              "rpm -q java-11-openjdk-devel || { echo 'Error: java-11-openjdk-devel not installed'; exit 1; }",
              "rpm -q glibc || { echo 'Error: glibc not installed'; exit 1; }",
              "rpm -q libgcc || { echo 'Error: libgcc not installed'; exit 1; }",
              "rpm -q rng-tools || { echo 'Error: rng-tools not installed'; exit 1; }",
              "rpm -q mariadb || { echo 'Error: mariadb not installed'; exit 1; }"
            ]
          }
        },
        {
          name   = "SetHostName_AutoStartService_ConfigGlideProperties_SetJavaHomeProfile"
          action = "ExecuteBash"
          inputs = {
            commands = [
              "sudo hostnamectl set-hostname dev",
              "sudo cp /tmp/snc_dev.service /etc/systemd/system",
              "sudo systemctl enable snc_dev.service",
              "sudo cp /tmp/glide.db.properties /glide/nodes/dev_16000/conf",
              "sudo cp /tmp/glide.properties /glide/nodes/dev_16000/conf",
              "sudo ln -s /etc/systemd/system/snc_dev2.service /etc/systemd/system/multi-user.target.wants/snc_dev2.service",
              "echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' | sudo tee /etc/profile.d/jdk_home.sh",
              "echo 'export PATH=$PATH:$JAVA_HOME/bin' | sudo tee /etc/profile.d/jdk_home.sh",
            ]
          }
        },
        {
          name   = "App_Install"
          action = "ExecuteBash"
          inputs = {
            commands = [
              "sudo mkdir -p /glide/nodes",
              "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk",
              "java -jar /tmp/glide-utah-12-21-2022__patch3-04-20-2023_05-04-2023_2316.zip --dst-dir /glide/nodes/dev_16000 install -n dev -p 16000",
              "chown -R servicenow: /glide/nodes/dev_16000",
              "su - servicenow"
            ]
          }
        }
      ]
    }]
    schemaVersion = 1.0
  })
}

/*
# ServiceNow AMI - Amazon Linux 2 with No Custom Components
module "beskar_adcp_integrations_snow_ec2_image_builder" {
  source                                             = "./modules/beskar_image_builder"
  name_prefix                                        = "int_snow_ec2"
  s3_beskar_config_files_id                          = module.beskar_shared_resources.s3_beskar_config_files_id
  image_recipe_version                               = "0.0.1"
  parent_image                                       = local.al2_image
  accounts_to_share                                  = [local.kr_sandbox_gov_account_id] #accounts to propogate image to
  default_tags                                       = local.required_tags_adcpint
  vpc_id                                             = module.beskar_forge_vpc.vpc_id
  subnet_id                                          = module.beskar_forge_vpc.private_subnets[0]
  security_group_id                                  = module.beskar_forge_vpc.default_security_group_id
  sns_topic_arn_send_to_mattermost                   = module.beskar_shared_resources.sns_topic_arn_send_to_mattermost
  build_and_test_instance_profile_name               = module.beskar_shared_resources.beskar_forge_instance_profile_name
  kms_key_id                                         = module.beskar_shared_resources.ec2_image_builder_encryption_key_arn
  component_edr_agent_arn                            = module.beskar_shared_resources.al2_component_crowdstrike_falcon_agent_arn
  component_logging_agent_arn                        = module.beskar_shared_resources.al2_component_logging_metrics_fluent-bit_arn
  component_harden_os_arn                            = module.beskar_shared_resources.al2_component_cis_os_harden_arn
  component_enable_kernel_livepatching_arn           = module.beskar_shared_resources.al2_component_enable_kernel_livepatching_arn
  component_security_scheduled_automatic_updates_arn = module.beskar_shared_resources.al2_component_security_updates_daily_yum_cron_arn
  component_scap_compliance_checker_arn              = module.beskar_shared_resources.al2_component_scap_compliance_checker_arn

  custom_components = [aws_imagebuilder_component.snow_int_ec2_build.arn] # it is a barebones image
}
*/