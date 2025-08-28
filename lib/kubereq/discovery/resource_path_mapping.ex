defmodule Kubereq.Discovery.ResourcePathMapping do
  @moduledoc false
  @spec lookup(key :: String.t()) :: String.t() | nil
  def lookup(key) do
    %{
      "APIService" => "apis/apiregistration.k8s.io/v1/apiservices/:name",
      "Binding" => "api/v1/namespaces/:namespace/bindings/:name",
      "CSIDriver" => "apis/storage.k8s.io/v1/csidrivers/:name",
      "CSINode" => "apis/storage.k8s.io/v1/csinodes/:name",
      "CSIStorageCapacity" =>
        "apis/storage.k8s.io/v1/namespaces/:namespace/csistoragecapacities/:name",
      "CertificateSigningRequest" =>
        "apis/certificates.k8s.io/v1/certificatesigningrequests/:name",
      "ClusterRole" => "apis/rbac.authorization.k8s.io/v1/clusterroles/:name",
      "ClusterRoleBinding" => "apis/rbac.authorization.k8s.io/v1/clusterrolebindings/:name",
      "ClusterTrustBundle" => "apis/certificates.k8s.io/v1alpha1/clustertrustbundles/:name",
      "ComponentStatus" => "api/v1/componentstatuses/:name",
      "ConfigMap" => "api/v1/namespaces/:namespace/configmaps/:name",
      "ControllerRevision" => "apis/apps/v1/namespaces/:namespace/controllerrevisions/:name",
      "CronJob" => "apis/batch/v1/namespaces/:namespace/cronjobs/:name",
      "CustomResourceDefinition" =>
        "apis/apiextensions.k8s.io/v1/customresourcedefinitions/:name",
      "DaemonSet" => "apis/apps/v1/namespaces/:namespace/daemonsets/:name",
      "Deployment" => "apis/apps/v1/namespaces/:namespace/deployments/:name",
      "DeviceClass" => "apis/resource.k8s.io/v1beta1/deviceclasses/:name",
      "DeviceTaintRule" => "apis/resource.k8s.io/v1alpha3/devicetaintrules/:name",
      "EndpointSlice" => "apis/discovery.k8s.io/v1/namespaces/:namespace/endpointslices/:name",
      "Endpoints" => "api/v1/namespaces/:namespace/endpoints/:name",
      "Event" => "apis/events.k8s.io/v1/namespaces/:namespace/events/:name",
      "FlowSchema" => "apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/:name",
      "HorizontalPodAutoscaler" =>
        "apis/autoscaling/v1/namespaces/:namespace/horizontalpodautoscalers/:name",
      "IPAddress" => "apis/networking.k8s.io/v1beta1/ipaddresses/:name",
      "Ingress" => "apis/networking.k8s.io/v1/namespaces/:namespace/ingresses/:name",
      "IngressClass" => "apis/networking.k8s.io/v1/ingressclasses/:name",
      "Job" => "apis/batch/v1/namespaces/:namespace/jobs/:name",
      "Lease" => "apis/coordination.k8s.io/v1/namespaces/:namespace/leases/:name",
      "LeaseCandidate" =>
        "apis/coordination.k8s.io/v1alpha2/namespaces/:namespace/leasecandidates/:name",
      "LimitRange" => "api/v1/namespaces/:namespace/limitranges/:name",
      "LocalSubjectAccessReview" =>
        "apis/authorization.k8s.io/v1/namespaces/:namespace/localsubjectaccessreviews/:name",
      "MutatingAdmissionPolicy" =>
        "apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicies/:name",
      "MutatingAdmissionPolicyBinding" =>
        "apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicybindings/:name",
      "MutatingWebhookConfiguration" =>
        "apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations/:name",
      "Namespace" => "api/v1/namespaces/:name",
      "NetworkPolicy" => "apis/networking.k8s.io/v1/namespaces/:namespace/networkpolicies/:name",
      "Node" => "api/v1/nodes/:name",
      "PersistentVolume" => "api/v1/persistentvolumes/:name",
      "PersistentVolumeClaim" => "api/v1/namespaces/:namespace/persistentvolumeclaims/:name",
      "Pod" => "api/v1/namespaces/:namespace/pods/:name",
      "PodCertificateRequest" =>
        "apis/certificates.k8s.io/v1alpha1/namespaces/:namespace/podcertificaterequests/:name",
      "PodDisruptionBudget" => "apis/policy/v1/namespaces/:namespace/poddisruptionbudgets/:name",
      "PodTemplate" => "api/v1/namespaces/:namespace/podtemplates/:name",
      "PriorityClass" => "apis/scheduling.k8s.io/v1/priorityclasses/:name",
      "PriorityLevelConfiguration" =>
        "apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/:name",
      "ReplicaSet" => "apis/apps/v1/namespaces/:namespace/replicasets/:name",
      "ReplicationController" => "api/v1/namespaces/:namespace/replicationcontrollers/:name",
      "ResourceClaim" =>
        "apis/resource.k8s.io/v1beta1/namespaces/:namespace/resourceclaims/:name",
      "ResourceClaimTemplate" =>
        "apis/resource.k8s.io/v1beta1/namespaces/:namespace/resourceclaimtemplates/:name",
      "ResourceQuota" => "api/v1/namespaces/:namespace/resourcequotas/:name",
      "ResourceSlice" => "apis/resource.k8s.io/v1beta1/resourceslices/:name",
      "Role" => "apis/rbac.authorization.k8s.io/v1/namespaces/:namespace/roles/:name",
      "RoleBinding" =>
        "apis/rbac.authorization.k8s.io/v1/namespaces/:namespace/rolebindings/:name",
      "RuntimeClass" => "apis/node.k8s.io/v1/runtimeclasses/:name",
      "Secret" => "api/v1/namespaces/:namespace/secrets/:name",
      "SelfSubjectAccessReview" => "apis/authorization.k8s.io/v1/selfsubjectaccessreviews/:name",
      "SelfSubjectReview" => "apis/authentication.k8s.io/v1/selfsubjectreviews/:name",
      "SelfSubjectRulesReview" => "apis/authorization.k8s.io/v1/selfsubjectrulesreviews/:name",
      "Service" => "api/v1/namespaces/:namespace/services/:name",
      "ServiceAccount" => "api/v1/namespaces/:namespace/serviceaccounts/:name",
      "ServiceCIDR" => "apis/networking.k8s.io/v1beta1/servicecidrs/:name",
      "StatefulSet" => "apis/apps/v1/namespaces/:namespace/statefulsets/:name",
      "StorageClass" => "apis/storage.k8s.io/v1/storageclasses/:name",
      "StorageVersion" => "apis/internal.apiserver.k8s.io/v1alpha1/storageversions/:name",
      "StorageVersionMigration" =>
        "apis/storagemigration.k8s.io/v1alpha1/storageversionmigrations/:name",
      "SubjectAccessReview" => "apis/authorization.k8s.io/v1/subjectaccessreviews/:name",
      "TokenReview" => "apis/authentication.k8s.io/v1/tokenreviews/:name",
      "ValidatingAdmissionPolicy" =>
        "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/:name",
      "ValidatingAdmissionPolicyBinding" =>
        "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings/:name",
      "ValidatingWebhookConfiguration" =>
        "apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations/:name",
      "VolumeAttachment" => "apis/storage.k8s.io/v1/volumeattachments/:name",
      "VolumeAttributesClass" => "apis/storage.k8s.io/v1alpha1/volumeattributesclasses/:name",
      "admissionregistration.k8s.io/v1/MutatingWebhookConfiguration" =>
        "apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations/:name",
      "admissionregistration.k8s.io/v1/ValidatingAdmissionPolicy" =>
        "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/:name",
      "admissionregistration.k8s.io/v1/ValidatingAdmissionPolicyBinding" =>
        "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings/:name",
      "admissionregistration.k8s.io/v1/ValidatingWebhookConfiguration" =>
        "apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations/:name",
      "admissionregistration.k8s.io/v1alpha1/MutatingAdmissionPolicy" =>
        "apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicies/:name",
      "admissionregistration.k8s.io/v1alpha1/MutatingAdmissionPolicyBinding" =>
        "apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicybindings/:name",
      "admissionregistration.k8s.io/v1beta1/MutatingAdmissionPolicy" =>
        "apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicies/:name",
      "admissionregistration.k8s.io/v1beta1/MutatingAdmissionPolicyBinding" =>
        "apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicybindings/:name",
      "apiextensions.k8s.io/v1/CustomResourceDefinition" =>
        "apis/apiextensions.k8s.io/v1/customresourcedefinitions/:name",
      "apiregistration.k8s.io/v1/APIService" =>
        "apis/apiregistration.k8s.io/v1/apiservices/:name",
      "apps/v1/ControllerRevision" =>
        "apis/apps/v1/namespaces/:namespace/controllerrevisions/:name",
      "apps/v1/DaemonSet" => "apis/apps/v1/namespaces/:namespace/daemonsets/:name",
      "apps/v1/Deployment" => "apis/apps/v1/namespaces/:namespace/deployments/:name",
      "apps/v1/ReplicaSet" => "apis/apps/v1/namespaces/:namespace/replicasets/:name",
      "apps/v1/StatefulSet" => "apis/apps/v1/namespaces/:namespace/statefulsets/:name",
      "authentication.k8s.io/v1/SelfSubjectReview" =>
        "apis/authentication.k8s.io/v1/selfsubjectreviews/:name",
      "authentication.k8s.io/v1/TokenReview" =>
        "apis/authentication.k8s.io/v1/tokenreviews/:name",
      "authorization.k8s.io/v1/LocalSubjectAccessReview" =>
        "apis/authorization.k8s.io/v1/namespaces/:namespace/localsubjectaccessreviews/:name",
      "authorization.k8s.io/v1/SelfSubjectAccessReview" =>
        "apis/authorization.k8s.io/v1/selfsubjectaccessreviews/:name",
      "authorization.k8s.io/v1/SelfSubjectRulesReview" =>
        "apis/authorization.k8s.io/v1/selfsubjectrulesreviews/:name",
      "authorization.k8s.io/v1/SubjectAccessReview" =>
        "apis/authorization.k8s.io/v1/subjectaccessreviews/:name",
      "autoscaling/v1/HorizontalPodAutoscaler" =>
        "apis/autoscaling/v1/namespaces/:namespace/horizontalpodautoscalers/:name",
      "autoscaling/v2/HorizontalPodAutoscaler" =>
        "apis/autoscaling/v2/namespaces/:namespace/horizontalpodautoscalers/:name",
      "batch/v1/CronJob" => "apis/batch/v1/namespaces/:namespace/cronjobs/:name",
      "batch/v1/Job" => "apis/batch/v1/namespaces/:namespace/jobs/:name",
      "certificates.k8s.io/v1/CertificateSigningRequest" =>
        "apis/certificates.k8s.io/v1/certificatesigningrequests/:name",
      "certificates.k8s.io/v1alpha1/ClusterTrustBundle" =>
        "apis/certificates.k8s.io/v1alpha1/clustertrustbundles/:name",
      "certificates.k8s.io/v1alpha1/PodCertificateRequest" =>
        "apis/certificates.k8s.io/v1alpha1/namespaces/:namespace/podcertificaterequests/:name",
      "certificates.k8s.io/v1beta1/ClusterTrustBundle" =>
        "apis/certificates.k8s.io/v1beta1/clustertrustbundles/:name",
      "coordination.k8s.io/v1/Lease" =>
        "apis/coordination.k8s.io/v1/namespaces/:namespace/leases/:name",
      "coordination.k8s.io/v1alpha2/LeaseCandidate" =>
        "apis/coordination.k8s.io/v1alpha2/namespaces/:namespace/leasecandidates/:name",
      "coordination.k8s.io/v1beta1/LeaseCandidate" =>
        "apis/coordination.k8s.io/v1beta1/namespaces/:namespace/leasecandidates/:name",
      "discovery.k8s.io/v1/EndpointSlice" =>
        "apis/discovery.k8s.io/v1/namespaces/:namespace/endpointslices/:name",
      "events.k8s.io/v1/Event" => "apis/events.k8s.io/v1/namespaces/:namespace/events/:name",
      "flowcontrol.apiserver.k8s.io/v1/FlowSchema" =>
        "apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/:name",
      "flowcontrol.apiserver.k8s.io/v1/PriorityLevelConfiguration" =>
        "apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/:name",
      "internal.apiserver.k8s.io/v1alpha1/StorageVersion" =>
        "apis/internal.apiserver.k8s.io/v1alpha1/storageversions/:name",
      "networking.k8s.io/v1/IPAddress" => "apis/networking.k8s.io/v1/ipaddresses/:name",
      "networking.k8s.io/v1/Ingress" =>
        "apis/networking.k8s.io/v1/namespaces/:namespace/ingresses/:name",
      "networking.k8s.io/v1/IngressClass" => "apis/networking.k8s.io/v1/ingressclasses/:name",
      "networking.k8s.io/v1/NetworkPolicy" =>
        "apis/networking.k8s.io/v1/namespaces/:namespace/networkpolicies/:name",
      "networking.k8s.io/v1/ServiceCIDR" => "apis/networking.k8s.io/v1/servicecidrs/:name",
      "networking.k8s.io/v1beta1/IPAddress" => "apis/networking.k8s.io/v1beta1/ipaddresses/:name",
      "networking.k8s.io/v1beta1/ServiceCIDR" =>
        "apis/networking.k8s.io/v1beta1/servicecidrs/:name",
      "node.k8s.io/v1/RuntimeClass" => "apis/node.k8s.io/v1/runtimeclasses/:name",
      "policy/v1/PodDisruptionBudget" =>
        "apis/policy/v1/namespaces/:namespace/poddisruptionbudgets/:name",
      "rbac.authorization.k8s.io/v1/ClusterRole" =>
        "apis/rbac.authorization.k8s.io/v1/clusterroles/:name",
      "rbac.authorization.k8s.io/v1/ClusterRoleBinding" =>
        "apis/rbac.authorization.k8s.io/v1/clusterrolebindings/:name",
      "rbac.authorization.k8s.io/v1/Role" =>
        "apis/rbac.authorization.k8s.io/v1/namespaces/:namespace/roles/:name",
      "rbac.authorization.k8s.io/v1/RoleBinding" =>
        "apis/rbac.authorization.k8s.io/v1/namespaces/:namespace/rolebindings/:name",
      "resource.k8s.io/v1/DeviceClass" => "apis/resource.k8s.io/v1/deviceclasses/:name",
      "resource.k8s.io/v1/ResourceClaim" =>
        "apis/resource.k8s.io/v1/namespaces/:namespace/resourceclaims/:name",
      "resource.k8s.io/v1/ResourceClaimTemplate" =>
        "apis/resource.k8s.io/v1/namespaces/:namespace/resourceclaimtemplates/:name",
      "resource.k8s.io/v1/ResourceSlice" => "apis/resource.k8s.io/v1/resourceslices/:name",
      "resource.k8s.io/v1alpha3/DeviceTaintRule" =>
        "apis/resource.k8s.io/v1alpha3/devicetaintrules/:name",
      "resource.k8s.io/v1beta1/DeviceClass" => "apis/resource.k8s.io/v1beta1/deviceclasses/:name",
      "resource.k8s.io/v1beta1/ResourceClaim" =>
        "apis/resource.k8s.io/v1beta1/namespaces/:namespace/resourceclaims/:name",
      "resource.k8s.io/v1beta1/ResourceClaimTemplate" =>
        "apis/resource.k8s.io/v1beta1/namespaces/:namespace/resourceclaimtemplates/:name",
      "resource.k8s.io/v1beta1/ResourceSlice" =>
        "apis/resource.k8s.io/v1beta1/resourceslices/:name",
      "resource.k8s.io/v1beta2/DeviceClass" => "apis/resource.k8s.io/v1beta2/deviceclasses/:name",
      "resource.k8s.io/v1beta2/ResourceClaim" =>
        "apis/resource.k8s.io/v1beta2/namespaces/:namespace/resourceclaims/:name",
      "resource.k8s.io/v1beta2/ResourceClaimTemplate" =>
        "apis/resource.k8s.io/v1beta2/namespaces/:namespace/resourceclaimtemplates/:name",
      "resource.k8s.io/v1beta2/ResourceSlice" =>
        "apis/resource.k8s.io/v1beta2/resourceslices/:name",
      "scheduling.k8s.io/v1/PriorityClass" => "apis/scheduling.k8s.io/v1/priorityclasses/:name",
      "storage.k8s.io/v1/CSIDriver" => "apis/storage.k8s.io/v1/csidrivers/:name",
      "storage.k8s.io/v1/CSINode" => "apis/storage.k8s.io/v1/csinodes/:name",
      "storage.k8s.io/v1/CSIStorageCapacity" =>
        "apis/storage.k8s.io/v1/namespaces/:namespace/csistoragecapacities/:name",
      "storage.k8s.io/v1/StorageClass" => "apis/storage.k8s.io/v1/storageclasses/:name",
      "storage.k8s.io/v1/VolumeAttachment" => "apis/storage.k8s.io/v1/volumeattachments/:name",
      "storage.k8s.io/v1/VolumeAttributesClass" =>
        "apis/storage.k8s.io/v1/volumeattributesclasses/:name",
      "storage.k8s.io/v1alpha1/VolumeAttributesClass" =>
        "apis/storage.k8s.io/v1alpha1/volumeattributesclasses/:name",
      "storage.k8s.io/v1beta1/VolumeAttributesClass" =>
        "apis/storage.k8s.io/v1beta1/volumeattributesclasses/:name",
      "storagemigration.k8s.io/v1alpha1/StorageVersionMigration" =>
        "apis/storagemigration.k8s.io/v1alpha1/storageversionmigrations/:name",
      "v1/Binding" => "api/v1/namespaces/:namespace/bindings/:name",
      "v1/ComponentStatus" => "api/v1/componentstatuses/:name",
      "v1/ConfigMap" => "api/v1/namespaces/:namespace/configmaps/:name",
      "v1/Endpoints" => "api/v1/namespaces/:namespace/endpoints/:name",
      "v1/Event" => "api/v1/namespaces/:namespace/events/:name",
      "v1/LimitRange" => "api/v1/namespaces/:namespace/limitranges/:name",
      "v1/Namespace" => "api/v1/namespaces/:name",
      "v1/Node" => "api/v1/nodes/:name",
      "v1/PersistentVolume" => "api/v1/persistentvolumes/:name",
      "v1/PersistentVolumeClaim" => "api/v1/namespaces/:namespace/persistentvolumeclaims/:name",
      "v1/Pod" => "api/v1/namespaces/:namespace/pods/:name",
      "v1/PodTemplate" => "api/v1/namespaces/:namespace/podtemplates/:name",
      "v1/ReplicationController" => "api/v1/namespaces/:namespace/replicationcontrollers/:name",
      "v1/ResourceQuota" => "api/v1/namespaces/:namespace/resourcequotas/:name",
      "v1/Secret" => "api/v1/namespaces/:namespace/secrets/:name",
      "v1/Service" => "api/v1/namespaces/:namespace/services/:name",
      "v1/ServiceAccount" => "api/v1/namespaces/:namespace/serviceaccounts/:name"
    }[key]
  end
end
