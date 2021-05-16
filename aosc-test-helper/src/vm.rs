use std::io::{Seek, SeekFrom, Write};

use anyhow::Result;
use rand::random;
use sailfish::TemplateOnce;
use tempfile::NamedTempFile;
use uuid::Uuid;
use virt::{
    connect::Connect,
    domain::Domain,
};

const DEFAULT_VM_RAM: usize = 1024 * 1024 * 1;
const DEFAULT_VM_CPU: usize = 2;

#[derive(TemplateOnce)]
#[template(path = "vm-efi.xml.stpl")]
pub struct VirtTemplate {
    pub name: String,
    uuid: String,
    memory: usize,
    vcpu: usize,
    pub nvram: String,
    image_path: String,
    use_gl: bool,
}

impl VirtTemplate {
    pub fn new(
        name: String,
        memory: usize,
        vcpu: usize,
        nvram: String,
        image_path: String,
        use_gl: bool,
    ) -> VirtTemplate {
        VirtTemplate {
            name,
            memory,
            vcpu,
            nvram,
            image_path,
            use_gl,
            uuid: Uuid::new_v4().to_string(),
        }
    }
}

pub fn create_vm(xml: &str) -> Result<Domain> {
    let conn = Connect::open("qemu:///system")?;
    let domain = Domain::create_xml(&conn, xml, 0)?;

    Ok(domain)
}

pub fn generate_vm_spec(image_path: &str, vcpu: Option<usize>, memory: Option<usize>, use_gl: bool) -> Result<VirtTemplate> {
    let name = format!("alice-{:x}", random::<u32>());
    // create a temporary NVRAM image
    let mut nvram = NamedTempFile::new()?;
    nvram.seek(SeekFrom::Start(4096 - 1))?;
    nvram.write(&[0])?;
    let (_, nvram_path) = nvram.keep()?;

    let vm_xml = VirtTemplate::new(
        name,
        memory.unwrap_or(DEFAULT_VM_RAM),
        vcpu.unwrap_or(DEFAULT_VM_CPU),
        nvram_path.to_string_lossy().to_string(),
        image_path.to_string(),
        use_gl,
    );

    Ok(vm_xml)
}
