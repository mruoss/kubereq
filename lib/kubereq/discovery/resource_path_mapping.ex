defmodule(Kubereq.Discovery.ResourcePathMapping) do
  def(mapping()) do
    %{
      "v1/Service" => "api/v1/namespaces/:namespace/services/:name",
      "rbac.authorization.k8s.io/v1/ClusterRole" =>
        "apis/rbac.authorization.k8s.io/v1/clusterroles/:name",
      "admissionregistration.k8s.io/v1/MutatingWebhookConfiguration" =>
        "apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations/:name",
      "admissionregistration.k8s.io/v1/ValidatingAdmissionPolicyBinding" =>
        "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings/:name",
      "resource.k8s.io/v1alpha3/ResourceClaimTemplate" =>
        "apis/resource.k8s.io/v1alpha3/namespaces/:namespace/resourceclaimtemplates/:name",
      "authorization.k8s.io/v1/SelfSubjectRulesReview" =>
        "apis/authorization.k8s.io/v1/selfsubjectrulesreviews/:name",
      "authentication.k8s.io/v1/TokenReview" =>
        "apis/authentication.k8s.io/v1/tokenreviews/:name",
      "storage.k8s.io/v1alpha1/VolumeAttributesClass" =>
        "apis/storage.k8s.io/v1alpha1/volumeattributesclasses/:name",
      "storage.k8s.io/v1/CSIDriver" => "apis/storage.k8s.io/v1/csidrivers/:name",
      "storage.k8s.io/v1/CSIStorageCapacity" =>
        "apis/storage.k8s.io/v1/namespaces/:namespace/csistoragecapacities/:name",
      "v1/ServiceAccount" => "api/v1/namespaces/:namespace/serviceaccounts/:name",
      "autoscaling/v1/HorizontalPodAutoscaler" =>
        "apis/autoscaling/v1/namespaces/:namespace/horizontalpodautoscalers/:name",
      "coordination.k8s.io/v1alpha1/LeaseCandidate" =>
        "apis/coordination.k8s.io/v1alpha1/namespaces/:namespace/leasecandidates/:name",
      "storage.k8s.io/v1/CSINode" => "apis/storage.k8s.io/v1/csinodes/:name",
      "resource.k8s.io/v1alpha3/PodSchedulingContext" =>
        "apis/resource.k8s.io/v1alpha3/namespaces/:namespace/podschedulingcontexts/:name",
      "authentication.k8s.io/v1beta1/SelfSubjectReview" =>
        "apis/authentication.k8s.io/v1beta1/selfsubjectreviews/:name",
      "admissionregistration.k8s.io/v1alpha1/ValidatingAdmissionPolicy" =>
        "apis/admissionregistration.k8s.io/v1alpha1/validatingadmissionpolicies/:name",
      "rbac.authorization.k8s.io/v1/RoleBinding" =>
        "apis/rbac.authorization.k8s.io/v1/namespaces/:namespace/rolebindings/:name",
      "apiextensions.k8s.io/v1/CustomResourceDefinition" =>
        "apis/apiextensions.k8s.io/v1/customresourcedefinitions/:name",
      "node.k8s.io/v1/RuntimeClass" => "apis/node.k8s.io/v1/runtimeclasses/:name",
      "apps/v1/StatefulSet" => "apis/apps/v1/namespaces/:namespace/statefulsets/:name",
      "flowcontrol.apiserver.k8s.io/v1/PriorityLevelConfiguration" =>
        "apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/:name",
      "certificates.k8s.io/v1alpha1/ClusterTrustBundle" =>
        "apis/certificates.k8s.io/v1alpha1/clustertrustbundles/:name",
      "v1/Event" => "api/v1/namespaces/:namespace/events/:name",
      "apps/v1/ReplicaSet" => "apis/apps/v1/namespaces/:namespace/replicasets/:name",
      "authentication.k8s.io/v1alpha1/SelfSubjectReview" =>
        "apis/authentication.k8s.io/v1alpha1/selfsubjectreviews/:name",
      "v1/LimitRange" => "api/v1/namespaces/:namespace/limitranges/:name",
      "admissionregistration.k8s.io/v1alpha1/ValidatingAdmissionPolicyBinding" =>
        "apis/admissionregistration.k8s.io/v1alpha1/validatingadmissionpolicybindings/:name",
      "v1/ComponentStatus" => "api/v1/componentstatuses/:name",
      "events.k8s.io/v1/Event" => "apis/events.k8s.io/v1/namespaces/:namespace/events/:name",
      "v1/Node" => "api/v1/nodes/:name",
      "scheduling.k8s.io/v1/PriorityClass" => "apis/scheduling.k8s.io/v1/priorityclasses/:name",
      "resource.k8s.io/v1alpha3/DeviceClass" =>
        "apis/resource.k8s.io/v1alpha3/deviceclasses/:name",
      "v1/ResourceQuota" => "api/v1/namespaces/:namespace/resourcequotas/:name",
      "v1/Endpoints" => "api/v1/namespaces/:namespace/endpoints/:name",
      "v1/Pod" => "api/v1/namespaces/:namespace/pods/:name",
      "v1/PodTemplate" => "api/v1/namespaces/:namespace/podtemplates/:name",
      "v1/Namespace" => "api/v1/namespaces/:name",
      "storagemigration.k8s.io/v1alpha1/StorageVersionMigration" =>
        "apis/storagemigration.k8s.io/v1alpha1/storageversionmigrations/:name",
      "v1/Secret" => "api/v1/namespaces/:namespace/secrets/:name",
      "v1/PersistentVolumeClaim" => "api/v1/namespaces/:namespace/persistentvolumeclaims/:name",
      "apps/v1/Deployment" => "apis/apps/v1/namespaces/:namespace/deployments/:name",
      "batch/v1/CronJob" => "apis/batch/v1/namespaces/:namespace/cronjobs/:name",
      "resource.k8s.io/v1alpha3/ResourceSlice" =>
        "apis/resource.k8s.io/v1alpha3/resourceslices/:name",
      "admissionregistration.k8s.io/v1beta1/ValidatingAdmissionPolicy" =>
        "apis/admissionregistration.k8s.io/v1beta1/validatingadmissionpolicies/:name",
      "apps/v1/ControllerRevision" =>
        "apis/apps/v1/namespaces/:namespace/controllerrevisions/:name",
      "admissionregistration.k8s.io/v1/ValidatingAdmissionPolicy" =>
        "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/:name",
      "networking.k8s.io/v1/Ingress" =>
        "apis/networking.k8s.io/v1/namespaces/:namespace/ingresses/:name",
      "coordination.k8s.io/v1/Lease" =>
        "apis/coordination.k8s.io/v1/namespaces/:namespace/leases/:name",
      "authorization.k8s.io/v1/LocalSubjectAccessReview" =>
        "apis/authorization.k8s.io/v1/namespaces/:namespace/localsubjectaccessreviews/:name",
      "policy/v1/PodDisruptionBudget" =>
        "apis/policy/v1/namespaces/:namespace/poddisruptionbudgets/:name",
      "batch/v1/Job" => "apis/batch/v1/namespaces/:namespace/jobs/:name",
      "networking.k8s.io/v1/IngressClass" => "apis/networking.k8s.io/v1/ingressclasses/:name",
      "flowcontrol.apiserver.k8s.io/v1beta3/PriorityLevelConfiguration" =>
        "apis/flowcontrol.apiserver.k8s.io/v1beta3/prioritylevelconfigurations/:name",
      "networking.k8s.io/v1beta1/IPAddress" => "apis/networking.k8s.io/v1beta1/ipaddresses/:name",
      "flowcontrol.apiserver.k8s.io/v1beta3/FlowSchema" =>
        "apis/flowcontrol.apiserver.k8s.io/v1beta3/flowschemas/:name",
      "apiregistration.k8s.io/v1/APIService" =>
        "apis/apiregistration.k8s.io/v1/apiservices/:name",
      "flowcontrol.apiserver.k8s.io/v1/FlowSchema" =>
        "apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/:name",
      "networking.k8s.io/v1beta1/ServiceCIDR" =>
        "apis/networking.k8s.io/v1beta1/servicecidrs/:name",
      "v1/ConfigMap" => "api/v1/namespaces/:namespace/configmaps/:name",
      "authentication.k8s.io/v1/SelfSubjectReview" =>
        "apis/authentication.k8s.io/v1/selfsubjectreviews/:name",
      "authorization.k8s.io/v1/SubjectAccessReview" =>
        "apis/authorization.k8s.io/v1/subjectaccessreviews/:name",
      "v1/ReplicationController" => "api/v1/namespaces/:namespace/replicationcontrollers/:name",
      "v1/Binding" => "api/v1/namespaces/:namespace/bindings/:name",
      "internal.apiserver.k8s.io/v1alpha1/StorageVersion" =>
        "apis/internal.apiserver.k8s.io/v1alpha1/storageversions/:name",
      "storage.k8s.io/v1/StorageClass" => "apis/storage.k8s.io/v1/storageclasses/:name",
      "v1/PersistentVolume" => "api/v1/persistentvolumes/:name",
      "admissionregistration.k8s.io/v1beta1/ValidatingAdmissionPolicyBinding" =>
        "apis/admissionregistration.k8s.io/v1beta1/validatingadmissionpolicybindings/:name",
      "autoscaling/v2/HorizontalPodAutoscaler" =>
        "apis/autoscaling/v2/namespaces/:namespace/horizontalpodautoscalers/:name",
      "networking.k8s.io/v1/NetworkPolicy" =>
        "apis/networking.k8s.io/v1/namespaces/:namespace/networkpolicies/:name",
      "discovery.k8s.io/v1/EndpointSlice" =>
        "apis/discovery.k8s.io/v1/namespaces/:namespace/endpointslices/:name",
      "authorization.k8s.io/v1/SelfSubjectAccessReview" =>
        "apis/authorization.k8s.io/v1/selfsubjectaccessreviews/:name",
      "resource.k8s.io/v1alpha3/ResourceClaim" =>
        "apis/resource.k8s.io/v1alpha3/namespaces/:namespace/resourceclaims/:name",
      "certificates.k8s.io/v1/CertificateSigningRequest" =>
        "apis/certificates.k8s.io/v1/certificatesigningrequests/:name",
      "storage.k8s.io/v1beta1/VolumeAttributesClass" =>
        "apis/storage.k8s.io/v1beta1/volumeattributesclasses/:name",
      "admissionregistration.k8s.io/v1/ValidatingWebhookConfiguration" =>
        "apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations/:name",
      "rbac.authorization.k8s.io/v1/Role" =>
        "apis/rbac.authorization.k8s.io/v1/namespaces/:namespace/roles/:name",
      "rbac.authorization.k8s.io/v1/ClusterRoleBinding" =>
        "apis/rbac.authorization.k8s.io/v1/clusterrolebindings/:name",
      "apps/v1/DaemonSet" => "apis/apps/v1/namespaces/:namespace/daemonsets/:name",
      "storage.k8s.io/v1/VolumeAttachment" => "apis/storage.k8s.io/v1/volumeattachments/:name"
    }
  end
end
